import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discovery_card.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/identity_repository.dart';
import '../../services/phone_number.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/dial_code_phone_field.dart';

bool hasWhatsAppNumber(Identity identity) {
  return isValidE164Digits(identity.whatsappNumber);
}

/// Why the WhatsApp sheet opened — drives title + primary CTA copy.
enum WhatsAppGatePurpose {
  /// Browse ♥ — Screen A.
  like,

  /// Liked me → Accept — chat — Screen B.
  likeBack,

  /// Publish / other actions (generic continue).
  continueAction,
}

/// Returns true if WhatsApp is already saved, or the user just saved it.
/// Returns false if they cancel. Use before like, like-back, or publish.
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
};

@visibleForTesting
String whatsAppGateCta(WhatsAppGatePurpose purpose) => switch (purpose) {
  WhatsAppGatePurpose.like => 'Save & like',
  WhatsAppGatePurpose.likeBack => 'Save & accept',
  WhatsAppGatePurpose.continueAction => 'Save & continue',
};

@visibleForTesting
String whatsAppGateBody(WhatsAppGatePurpose purpose) => switch (purpose) {
  WhatsAppGatePurpose.like =>
    'People who like you back need a way to reach you. '
        'Your number stays private until both are interested '
        'and phone-verified.',
  WhatsAppGatePurpose.likeBack =>
    'To accept and chat, add WhatsApp. '
        'Your number stays private until both are interested '
        'and phone-verified.',
  WhatsAppGatePurpose.continueAction =>
    'Others need a way to reach you after a match. '
        'Your number stays private until both are interested '
        'and phone-verified.',
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
    _phone = TextEditingController(text: parts.national);
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
