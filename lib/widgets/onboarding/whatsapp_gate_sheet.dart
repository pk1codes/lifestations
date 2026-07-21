import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discovery_card.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/identity_repository.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';

bool hasWhatsAppNumber(Identity identity) {
  final digits = identity.whatsappNumber.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15;
}

/// Returns true if WhatsApp is already saved, or the user just saved it.
/// Returns false if they cancel. Use before like, like-back, or publish.
///
/// After a number exists locally, re-syncs the contact vault under a live
/// auth uid so unlockContact does not fail with "Phone not ready".
Future<bool> ensureWhatsAppForAction(BuildContext context) async {
  final store = context.read<IdentityStore>();
  if (!hasWhatsAppNumber(store.identity)) {
    if (!context.mounted) return false;
    final ok = await showWhatsAppGateSheet(context);
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

Future<bool> showWhatsAppGateSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _WhatsAppGateSheet(),
  );
  return result ?? false;
}

class _WhatsAppGateSheet extends StatefulWidget {
  const _WhatsAppGateSheet();

  @override
  State<_WhatsAppGateSheet> createState() => _WhatsAppGateSheetState();
}

class _WhatsAppGateSheetState extends State<_WhatsAppGateSheet> {
  late final TextEditingController _phone;
  final _formKey = GlobalKey<FormState>();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<IdentityStore>().identity.whatsappNumber;
    _phone = TextEditingController(text: current);
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
      final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
      await store.save(store.identity.copyWith(whatsappNumber: digits));
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
              'Add WhatsApp to continue',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Others need a way to reach you after a match. '
              'Your number stays private until both are interested '
              'and phone-verified.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: '+91 98765 43210',
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 8) return 'Enter at least 8 digits';
                if (digits.length > 15) return 'Use at most 15 digits';
                return null;
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
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
                  : const Text('Save & continue'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
