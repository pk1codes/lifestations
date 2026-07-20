import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/contact_service.dart';
import '../../services/firebase_bootstrap.dart';
import '../../state/app_stores.dart';

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

class OtpSheet extends StatefulWidget {
  const OtpSheet({this.auth, this.throttle, super.key});
  final FirebaseAuth? auth;
  final OtpThrottle? throttle;

  @override
  State<OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<OtpSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  late final OtpThrottle _throttle = widget.throttle ?? OtpThrottle();
  String? _verificationId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
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
          'Verify & connect',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text('Browsing and liking never require verification.'),
        const SizedBox(height: 16),
        if (_verificationId == null)
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone with country code',
              hintText: '+91 98765 43210',
            ),
          )
        else
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: '6-digit OTP'),
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
          onPressed: _busy ? null : (_verificationId == null ? _send : _verify),
          child: Text(
            _busy
                ? 'Please wait…'
                : _verificationId == null
                ? 'Send OTP'
                : 'Verify OTP',
          ),
        ),
      ],
    ),
  );

  Future<void> _send() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      setState(() => _error = 'Enter at least 8 digits.');
      return;
    }
    final now = DateTime.now();
    if (!_throttle.record(now)) {
      setState(
        () => _error = 'Try again in ${_throttle.remaining(now).inSeconds}s.',
      );
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
      phoneNumber: _phone.text.trim().startsWith('+')
          ? _phone.text.trim()
          : '+91$digits',
      verificationCompleted: (credential) => _complete(credential),
      verificationFailed: (error) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = error.message ?? 'Could not send OTP.';
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
      setState(() => _error = 'Enter the 6-digit OTP.');
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
      await identity.save(identity.identity.copyWith(phoneVerified: true));
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message ?? 'Verification failed.';
        });
      }
    }
  }
}
