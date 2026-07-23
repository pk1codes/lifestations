import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discovery_card.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/identity_repository.dart';
import '../../services/phone_number.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/dial_code_phone_field.dart';
import 'otp_sheet.dart';

bool hasWhatsAppNumber(Identity identity) {
  return isValidE164Digits(identity.whatsappNumber);
}

/// Why the WhatsApp sheet opened — drives title + primary CTA copy.
enum WhatsAppGatePurpose {
  /// Browse ♥ — Screen A (legacy copy; like now uses OTP).
  like,

  /// Liked me → Accept (legacy copy; accept now uses OTP).
  likeBack,

  /// Publish / other actions (generic continue).
  continueAction,

  /// User chose a different number for WhatsApp / Telegram share.
  contactShare,
}

/// Returns true if WhatsApp is already saved, or the user just saved it.
/// Returns false if they cancel. Use before publish when a vault number is needed.
///
/// After a number exists locally, re-syncs the contact vault under a live
/// auth uid so unlockContact does not fail with "Phone not ready".
Future<bool> ensureWhatsAppForAction(
  BuildContext context, {
  WhatsAppGatePurpose purpose = WhatsAppGatePurpose.continueAction,
}) async {
  final store = context.read<IdentityStore>();
  if (!hasWhatsAppNumber(store.identity)) {
    if (!context.mounted) return false;
    final ok = await showWhatsAppGateSheet(context, purpose: purpose);
    if (!ok) return false;
  }
  try {
    await FirebaseBootstrap.waitUntilReady();
    if (FirebaseBootstrap.ready) {
      await FirebaseBootstrap.ensureSignedIn();
      await IdentityRepository().sync(store.identity);
    }
  } catch (_) {
    // Local number is enough to open forms / like; vault retries next time.
  }
  return hasWhatsAppNumber(store.identity);
}

/// WhatsApp / Telegram tap: verify phone if needed, then same-or-other number.
Future<bool> ensureContactShareForChat(BuildContext context) async {
  final verified = await ensurePhoneVerifiedForAction(context);
  if (!verified || !context.mounted) return false;

  final store = context.read<IdentityStore>();
  if (store.identity.contactShareChosen &&
      hasWhatsAppNumber(store.identity)) {
    return true;
  }

  final useSame = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final phone = store.identity.whatsappNumber;
      final label = phone.isEmpty
          ? 'your verified phone'
          : '+$phone';
      return AlertDialog(
        key: const Key('contact_share_choice_dialog'),
        title: const Text('WhatsApp number'),
        content: Text(
          'Use $label for WhatsApp and Telegram?',
        ),
        actions: [
          TextButton(
            key: const Key('contact_share_different'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Different number'),
          ),
          FilledButton(
            key: const Key('contact_share_same'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use same'),
          ),
        ],
      );
    },
  );

  if (!context.mounted || useSame == null) return false;

  if (useSame) {
    if (!hasWhatsAppNumber(store.identity)) {
      // Verified but empty local digits — collect once.
      final ok = await showWhatsAppGateSheet(
        context,
        purpose: WhatsAppGatePurpose.contactShare,
      );
      if (!ok || !context.mounted) return false;
    }
    await store.save(
      store.identity.copyWith(contactShareChosen: true),
    );
    try {
      await IdentityRepository().sync(store.identity);
    } catch (_) {}
    return hasWhatsAppNumber(store.identity);
  }

  final ok = await showWhatsAppGateSheet(
    context,
    purpose: WhatsAppGatePurpose.contactShare,
  );
  if (!ok || !context.mounted) return false;
  await store.save(
    store.identity.copyWith(contactShareChosen: true),
  );
  try {
    await IdentityRepository().sync(store.identity);
  } catch (_) {}
  return hasWhatsAppNumber(store.identity);
}

Future<bool> showWhatsAppGateSheet(
  BuildContext context, {
  WhatsAppGatePurpose purpose = WhatsAppGatePurpose.continueAction,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WhatsAppGateSheet(purpose: purpose),
  );
  return result ?? false;
}

@visibleForTesting
String whatsAppGateTitle(WhatsAppGatePurpose purpose) => switch (purpose) {
  WhatsAppGatePurpose.like => 'Add WhatsApp to like',
  WhatsAppGatePurpose.likeBack => 'Add WhatsApp to accept',
  WhatsAppGatePurpose.continueAction => 'Add WhatsApp to continue',
  WhatsAppGatePurpose.contactShare => 'WhatsApp for chat',
};

@visibleForTesting
String whatsAppGateCta(WhatsAppGatePurpose purpose) => switch (purpose) {
  WhatsAppGatePurpose.like => 'Save & like',
  WhatsAppGatePurpose.likeBack => 'Save & accept',
  WhatsAppGatePurpose.continueAction => 'Save & continue',
  WhatsAppGatePurpose.contactShare => 'Save number',
};

@visibleForTesting
String whatsAppGateBody(WhatsAppGatePurpose purpose) => switch (purpose) {
  WhatsAppGatePurpose.like =>
    'Add your number so matches can reach you. It stays private until both like.',
  WhatsAppGatePurpose.likeBack =>
    'Add your number to accept. It stays private until both like.',
  WhatsAppGatePurpose.continueAction =>
    'Add your number so matches can reach you. It stays private until both like.',
  WhatsAppGatePurpose.contactShare =>
    'This number is for WhatsApp only — not your login phone.',
};

class _WhatsAppGateSheet extends StatefulWidget {
  const _WhatsAppGateSheet({required this.purpose});

  final WhatsAppGatePurpose purpose;

  @override
  State<_WhatsAppGateSheet> createState() => _WhatsAppGateSheetState();
}

class _WhatsAppGateSheetState extends State<_WhatsAppGateSheet> {
  late final TextEditingController _phone;
  late PhoneDialCode _dial;
  final _formKey = GlobalKey<FormState>();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<IdentityStore>().identity;
    final parts = splitStoredPhone(
      current.whatsappNumber,
      fallback: PhoneDialCode.fromDigits(current.dialCodePreference),
    );
    _dial = parts.dial;
    _phone = TextEditingController(
      text: widget.purpose == WhatsAppGatePurpose.contactShare
          ? ''
          : parts.national,
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseBootstrap.waitUntilReady();
      if (FirebaseBootstrap.ready) {
        await FirebaseBootstrap.ensureSignedIn();
      }
      if (!mounted) return;
      final store = context.read<IdentityStore>();
      final e164 = toE164Digits(_dial, _phone.text);
      await store.save(
        store.identity.copyWith(
          whatsappNumber: e164,
          dialCodePreference: _dial.digits,
          contactShareChosen:
              widget.purpose == WhatsAppGatePurpose.contactShare
              ? true
              : store.identity.contactShareChosen,
        ),
      );
      // Force vault write even when public identity fields are incomplete.
      await IdentityRepository().sync(store.identity);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save WhatsApp. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purpose = widget.purpose;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              whatsAppGateTitle(purpose),
              key: const Key('whatsapp_gate_title'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              whatsAppGateBody(purpose),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            DialCodePhoneField(
              dial: _dial,
              controller: _phone,
              label: 'WhatsApp number',
              autofocus: true,
              onDialChanged: (code) => setState(() => _dial = code),
              onComplete: () {
                if (!_busy) unawaited(_saveAndContinue());
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('whatsapp_gate_save'),
              onPressed: _busy ? null : _saveAndContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                foregroundColor: Colors.white,
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(whatsAppGateCta(purpose)),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('whatsapp_gate_not_now'),
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
