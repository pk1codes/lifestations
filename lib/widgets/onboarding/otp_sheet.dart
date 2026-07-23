import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/contact_service.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/phone_number.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/dial_code_phone_field.dart';

/// Phone-only Firebase OTP (verify / sign-in). No name, city, or Account form.
Future<bool> showOtpSheet(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => OtpSheet(throttle: OtpThrottle(preferences: prefs)),
  );
  return result ?? false;
}

/// Like / Accept / publish: same verify path as Me → Account updates too.
///
/// Local `phoneVerified` alone is not enough — Firebase Auth must still have a
/// live phone session (multi-tab / second OTP can replace the signed-in user).
Future<bool> ensurePhoneVerifiedForAction(BuildContext context) async {
  final store = context.read<IdentityStore>();
  if (store.identity.phoneVerified && hasLivePhoneAuth()) {
    return true;
  }
  if (store.identity.phoneVerified && !hasLivePhoneAuth()) {
    // Stale UX flag after Auth was replaced or cleared (common with 2 tabs).
    await store.savePhoneVerification(phoneVerified: false);
  }
  if (!context.mounted) return false;
  final ok = await showOtpSheet(context);
  if (!ok || !context.mounted) return false;
  return context.read<IdentityStore>().identity.phoneVerified &&
      hasLivePhoneAuth();
}

/// Test hook — when set, [hasLivePhoneAuth] returns this instead of Auth.
@visibleForTesting
bool Function([FirebaseAuth?])? debugHasLivePhoneAuth;

/// True when Firebase Auth currently has a phone-linked user.
bool hasLivePhoneAuth([FirebaseAuth? auth]) {
  final override = debugHasLivePhoneAuth;
  if (override != null) return override(auth);
  try {
    final phone = (auth ?? FirebaseAuth.instance).currentUser?.phoneNumber
        ?.trim();
    return phone != null && phone.isNotEmpty;
  } catch (_) {
    return false;
  }
}

bool phoneBelongsToOtherAccount(FirebaseAuthException error) {
  return error.code == 'credential-already-in-use' ||
      error.code == 'account-exists-with-different-credential' ||
      error.code == 'provider-already-linked';
}

class OtpSheet extends StatefulWidget {
  const OtpSheet({
    this.auth,
    this.throttle,
    @visibleForTesting this.debugStartWithVerificationId,
    super.key,
  });
  final FirebaseAuth? auth;
  final OtpThrottle? throttle;

  /// Test-only: open directly on the 6-digit code step.
  @visibleForTesting
  final String? debugStartWithVerificationId;

  @override
  State<OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<OtpSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  late final OtpThrottle _throttle = widget.throttle ?? OtpThrottle();
  late PhoneDialCode _dial;
  String? _verificationId;
  ConfirmationResult? _webConfirmation;
  String? _error;
  bool _busy = false;
  Timer? _cooldownTicker;

  bool get _awaitingCode => _verificationId != null || _webConfirmation != null;

  @override
  void initState() {
    super.initState();
    final identity = context.read<IdentityStore>().identity;
    final wa = splitStoredPhone(
      identity.whatsappNumber,
      fallback: PhoneDialCode.fromDigits(identity.dialCodePreference),
    );
    _dial = wa.dial;
    _phone.text = wa.national;
    _verificationId = widget.debugStartWithVerificationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final left = _throttle.remaining(DateTime.now());
      if (left > Duration.zero) {
        _startCooldown(left);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(Duration duration) {
    var seconds = duration.inSeconds;
    if (seconds < 1) seconds = 60;
    _cooldownTicker?.cancel();
    setState(() => _error = 'Try again in ${seconds}s.');
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      seconds -= 1;
      setState(() {
        if (seconds <= 0) {
          _error = null;
          timer.cancel();
          _cooldownTicker = null;
        } else {
          _error = 'Try again in ${seconds}s.';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _awaitingCode ? 'Enter code' : 'Verify phone',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _awaitingCode
                ? 'Type the 6-digit code.'
                : 'Enter your phone. We send a one-time code.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (!_awaitingCode)
            DialCodePhoneField(
              dial: _dial,
              controller: _phone,
              label: 'Phone',
              autofocus: _phone.text.isEmpty,
              onDialChanged: (code) => setState(() => _dial = code),
              onComplete: () {
                if (!_busy && !_awaitingCode) unawaited(_send());
              },
            )
          else ...[
            Text(
              toFirebasePhone(_dial, _phone.text),
              key: const Key('otp_sent_to'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('otp_code_field'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: theme.textTheme.headlineSmall,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: '6-digit code',
                hintText: otpCodeHintExample,
              ),
              onChanged: (value) {
                if (!_busy && value.trim().length == 6) {
                  unawaited(_verify());
                }
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _verificationId = null;
                        _webConfirmation = null;
                        _code.clear();
                        _error = null;
                      }),
                child: const Text('Change number'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('otp_error'),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Keep buttons as backup; auto-runs when digits are complete.
          FilledButton(
            key: Key(_awaitingCode ? 'otp_confirm' : 'otp_send'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
            onPressed: _busy ? null : (_awaitingCode ? _verify : _send),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(_awaitingCode ? 'Confirm' : 'Send code'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final error = phoneFieldError(_dial, _phone.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final firebasePhone = toFirebasePhone(_dial, _phone.text);
    final now = DateTime.now();
    if (!_throttle.record(now)) {
      _startCooldown(_throttle.remaining(now));
      return;
    }
    unawaited(_claimRemoteOtpWindowBestEffort());

    if (!FirebaseBootstrap.ready) {
      setState(() => _error = 'Phone verification is unavailable offline.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseBootstrap.ensureSignedIn();
      final auth = widget.auth ?? FirebaseAuth.instance;
      if (kIsWeb) {
        await _sendWeb(auth, firebasePhone);
      } else {
        await _sendMobile(auth, firebasePhone);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyOtpError(error);
      });
    }
  }

  Future<void> _sendWeb(FirebaseAuth auth, String firebasePhone) async {
    final user = auth.currentUser;
    ConfirmationResult result;
    try {
      if (user != null && user.isAnonymous) {
        result = await user.linkWithPhoneNumber(firebasePhone);
      } else {
        result = await auth.signInWithPhoneNumber(firebasePhone);
      }
    } on FirebaseAuthException catch (error) {
      if (phoneBelongsToOtherAccount(error)) {
        result = await auth.signInWithPhoneNumber(firebasePhone);
      } else {
        rethrow;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _webConfirmation = result;
      _verificationId = result.verificationId;
      _error = null;
    });
  }

  Future<void> _sendMobile(FirebaseAuth auth, String firebasePhone) async {
    await auth.verifyPhoneNumber(
      phoneNumber: firebasePhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) => _applyPhoneCredential(credential),
      verificationFailed: (error) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = friendlyOtpError(error);
          });
        }
      },
      codeSent: (verificationId, _) {
        if (mounted) {
          setState(() {
            _busy = false;
            _verificationId = verificationId;
            _error = null;
          });
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _verificationId ??= verificationId;
        });
      },
    );
  }

  Future<void> _claimRemoteOtpWindowBestEffort() async {
    if (!FirebaseBootstrap.ready) return;
    final user = (widget.auth ?? FirebaseAuth.instance).currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.doc('otp_trackers/$uid').set({
        'uid': uid,
        'lastSentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('otp_trackers write skipped: $error');
      }
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_webConfirmation != null) {
        await _confirmWeb(code);
        return;
      }
      final id = _verificationId;
      if (id == null) {
        setState(() {
          _busy = false;
          _error = 'Send a code first.';
        });
        return;
      }
      await _applyPhoneCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyOtpError(error);
      });
    }
  }

  Future<void> _confirmWeb(String code) async {
    final auth = widget.auth ?? FirebaseAuth.instance;
    final confirmation = _webConfirmation!;
    try {
      await confirmation.confirm(code);
    } on FirebaseAuthException catch (error) {
      if (!phoneBelongsToOtherAccount(error)) rethrow;
      // Same person, other device/session — sign in as the existing phone user.
      await auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: confirmation.verificationId,
          smsCode: code,
        ),
      );
    }
    await _persistVerified();
  }

  /// Link anonymous → phone when possible; otherwise sign in (same phone = same user).
  Future<void> _applyPhoneCredential(PhoneAuthCredential credential) async {
    if (mounted) setState(() => _busy = true);
    try {
      final auth = widget.auth ?? FirebaseAuth.instance;
      final user = auth.currentUser;
      try {
        if (user != null && user.isAnonymous) {
          await user.linkWithCredential(credential);
        } else {
          await auth.signInWithCredential(credential);
        }
      } on FirebaseAuthException catch (error) {
        if (!phoneBelongsToOtherAccount(error)) rethrow;
        await auth.signInWithCredential(credential);
      }
      await _persistVerified();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyOtpError(error);
        });
      }
    }
  }

  Future<void> _persistVerified() async {
    final auth = widget.auth ?? FirebaseAuth.instance;
    final phone = auth.currentUser?.phoneNumber?.trim();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not verify phone. Try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    final identity = context.read<IdentityStore>();
    final e164 = toE164Digits(_dial, _phone.text);
    await identity.savePhoneVerification(
      phoneVerified: true,
      dialCodePreference: _dial.digits,
      whatsappNumber: e164.isNotEmpty ? e164 : identity.identity.whatsappNumber,
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// Maps Firebase phone-auth failures into short, human lines.
String friendlyOtpError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Check the phone number and try again.';
      case 'too-many-requests':
        return 'Too many tries. Wait a bit, then retry.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'That code is wrong or expired. Request a new code.';
      case 'session-expired':
        return 'Code expired. Send a new code.';
      case 'quota-exceeded':
        return 'SMS limit reached. Try again later.';
      case 'network-request-failed':
        return 'No network. Check connection and retry.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        // Handled by sign-in fallback; if it still surfaces, keep it plain.
        return 'Signing you in with this phone…';
      case 'captcha-check-failed':
        return 'Security check failed. Refresh and try again.';
      case 'operation-not-allowed':
        final detail = error.message?.trim() ?? '';
        if (detail.toLowerCase().contains('region') ||
            detail.toLowerCase().contains('sms')) {
          return 'SMS region blocked. Allow India and Kuwait in Firebase '
              'Authentication → Settings → SMS region policy.';
        }
        return 'Phone sign-in blocked by Firebase settings.';
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'App not authorized for phone auth.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty && message.length <= 100) {
          return message;
        }
        return 'Could not verify phone. Try again.';
    }
  }
  if (error is StateError) {
    return 'Could not start phone verify. Try again.';
  }
  return 'Could not verify phone. Try again.';
}
