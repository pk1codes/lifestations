import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/contact_service.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/phone_number.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/dial_code_phone_field.dart';
import 'whatsapp_gate_sheet.dart';

Future<bool> showOtpSheet(
  BuildContext context, {
  bool preferWhatsAppNumber = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => OtpSheet(
      throttle: OtpThrottle(preferences: prefs),
      preferWhatsAppNumber: preferWhatsAppNumber,
    ),
  );
  return result ?? false;
}

class OtpSheet extends StatefulWidget {
  const OtpSheet({
    this.auth,
    this.throttle,
    this.preferWhatsAppNumber = false,
    super.key,
  });
  final FirebaseAuth? auth;
  final OtpThrottle? throttle;

  /// When true (Account → Verify), start with the saved WhatsApp number.
  final bool preferWhatsAppNumber;

  @override
  State<OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<OtpSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  late final OtpThrottle _throttle = widget.throttle ?? OtpThrottle();
  late PhoneDialCode _dial;
  var _sameAsWhatsApp = false;
  String? _verificationId;
  String? _error;
  bool _busy = false;
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    final identity = context.read<IdentityStore>().identity;
    final wa = splitStoredPhone(
      identity.whatsappNumber,
      fallback: PhoneDialCode.fromDigits(identity.dialCodePreference),
    );
    // Default India (+91) when preference / WhatsApp dial is unset.
    _dial = wa.dial;
    if (widget.preferWhatsAppNumber && wa.national.isNotEmpty) {
      _sameAsWhatsApp = true;
      _phone.text = wa.national;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_throttle.remaining(DateTime.now()) > Duration.zero) {
        _startCooldownTicker();
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

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    void tick() {
      if (!mounted) return;
      final left = _throttle.remaining(DateTime.now());
      setState(() {
        if (left <= Duration.zero) {
          _error = null;
          _cooldownTicker?.cancel();
          _cooldownTicker = null;
        } else {
          _error = 'Try again in ${left.inSeconds}s.';
        }
      });
    }

    tick();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _applySameAsWhatsApp(bool value) {
    setState(() {
      _sameAsWhatsApp = value;
      if (!value) return;
      final wa = splitStoredPhone(
        context.read<IdentityStore>().identity.whatsappNumber,
        fallback: _dial,
      );
      _dial = wa.dial;
      _phone.text = wa.national;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasWa = hasWhatsAppNumber(context.watch<IdentityStore>().identity);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verify phone',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'We send an SMS code to this phone. '
            'This is not WhatsApp or Telegram.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (_verificationId == null) ...[
            DialCodePhoneField(
              dial: _dial,
              controller: _phone,
              label: 'Phone for SMS',
              autofocus: true,
              onDialChanged: (code) => setState(() {
                _dial = code;
                _sameAsWhatsApp = false;
              }),
            ),
            if (hasWa)
              CheckboxListTile(
                key: const Key('otp_same_as_whatsapp'),
                contentPadding: EdgeInsets.zero,
                value: _sameAsWhatsApp,
                onChanged: (v) => _applySameAsWhatsApp(v ?? false),
                title: const Text('Same as WhatsApp'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ] else
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(labelText: '6-digit SMS code'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : (_verificationId == null ? _send : _verify),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(
                    _verificationId == null ? 'Send SMS code' : 'Verify code',
                  ),
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
    // Must be E.164 with '+' for Firebase Auth (e.g. +919869610903).
    assert(
      firebasePhone.startsWith('+') && firebasePhone.length >= 9,
      'OTP requires Firebase E.164 phone, got: $firebasePhone',
    );
    final now = DateTime.now();
    if (!_throttle.record(now)) {
      _startCooldownTicker();
      return;
    }
    if (!await _claimRemoteOtpWindow()) {
      return;
    }
    if (!FirebaseBootstrap.ready) {
      if (kDebugMode) {
        if (!mounted) return;
        final identity = context.read<IdentityStore>();
        await identity.save(identity.identity.copyWith(phoneVerified: true));
        if (mounted) Navigator.pop(context, true);
        return;
      }
      setState(() => _error = 'Phone verification is unavailable offline.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = widget.auth ?? FirebaseAuth.instance;
    await auth.verifyPhoneNumber(
      phoneNumber: firebasePhone,
      verificationCompleted: (credential) => _complete(credential),
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
          });
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (mounted) _verificationId ??= verificationId;
      },
    );
  }

  Future<bool> _claimRemoteOtpWindow() async {
    if (!FirebaseBootstrap.ready) return true;
    final user = (widget.auth ?? FirebaseAuth.instance).currentUser;
    final uid = user?.uid;
    if (uid == null) return true;
    try {
      await FirebaseFirestore.instance.doc('otp_trackers/$uid').set({
        'uid': uid,
        'lastSentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Try again in 60s.');
      }
      return false;
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    await _complete(
      PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _code.text.trim(),
      ),
    );
  }

  Future<void> _complete(PhoneAuthCredential credential) async {
    setState(() => _busy = true);
    try {
      final auth = widget.auth ?? FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null && user.isAnonymous) {
        await user.linkWithCredential(credential);
      } else {
        await auth.signInWithCredential(credential);
      }
      if (!mounted) return;
      final identity = context.read<IdentityStore>();
      await identity.save(
        identity.identity.copyWith(
          phoneVerified: true,
          dialCodePreference: _dial.digits,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyOtpError(error);
        });
      }
    }
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
        return 'Code expired. Send a new SMS code.';
      case 'quota-exceeded':
        return 'SMS limit reached. Try again later.';
      case 'network-request-failed':
        return 'No network. Check connection and retry.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty && message.length <= 80) {
          return message;
        }
        return 'Could not verify phone. Try again.';
    }
  }
  return 'Could not verify phone. Try again.';
}
