import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../services/form_media_controller.dart';
import '../../services/phone_number.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/form_fields.dart';
import '../forms/photo_source_sheet.dart';
import 'otp_sheet.dart';

/// Optional profile only — phone verify lives in [showOtpSheet], not here.
Future<void> showIdentityForm(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _IdentityFormSheet(),
  );
}

class _IdentityFormSheet extends StatefulWidget {
  const _IdentityFormSheet();

  @override
  State<_IdentityFormSheet> createState() => _IdentityFormSheetState();
}

class _IdentityFormSheetState extends State<_IdentityFormSheet> {
  late final TextEditingController _name;
  late String _city;
  late String _language;
  final _formKey = GlobalKey<FormState>();
  late final FormMediaController _media;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<IdentityStore>().identity;
    _name = TextEditingController(text: current.displayName);
    _city = current.cityId.isEmpty ? 'mumbai' : current.cityId;
    _language = current.nativeLanguage.isEmpty
        ? 'Hindi'
        : current.nativeLanguage;
    _media = FormMediaController(domain: AppDomainId.marriage);
    _media.seedUrls(current.photoUrls);
    _media.addListener(_onMedia);
  }

  void _onMedia() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _media.removeListener(_onMedia);
    _media.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<bool> _pickPhoto(int slot) async {
    final source = await showPhotoSourceSheet(context, accent: AppColors.rose);
    if (source == null || !mounted) return false;
    return _media.pickAndUploadIdentity(slot: slot, source: source);
  }

  void _removePhoto(int slot) => _media.removeAt(slot);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final store = context.read<IdentityStore>();
      await store.save(
        store.identity.copyWith(
          displayName: _name.text.trim(),
          cityId: _city,
          cityLabel: cityLabels[_city] ?? _city,
          nativeLanguage: _language,
          photoUrls: List<String>.from(
            _media.urls.where((url) => url.trim().isNotEmpty),
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityStore>().identity;
    final phone = splitStoredPhone(identity.whatsappNumber);
    final phoneLabel = identity.whatsappNumber.isEmpty
        ? 'Not set'
        : '${phone.dial.label} ${phone.national}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Optional. Phone verify is separate.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.darkCream,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        identity.phoneVerified
                            ? Icons.verified
                            : Icons.phone_outlined,
                        color: AppColors.rose,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              identity.phoneVerified
                                  ? 'Phone verified'
                                  : 'Phone not verified',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              phoneLabel,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('account_open_phone_verify'),
                        onPressed: () async {
                          final ok = await showOtpSheet(context);
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Phone verified')),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          identity.phoneVerified ? 'Change' : 'Verify',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PhotoSlotStrip(
                urls: _media.urls,
                previews: _media.previews,
                minimum: 0,
                maximum: 1,
                accent: AppColors.rose,
                softAccent: AppColors.darkCream,
                busySlot: _media.busySlot,
                uploadProgress: _media.uploadProgress,
                errorText: _media.lastError,
                showTitle: false,
                motivation: '',
                hint: '',
                onPick: _pickPhoto,
                onRemove: _removePhoto,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                ),
              ),
              const SizedBox(height: 12),
              CityDropdown(
                value: _city,
                onChanged: (value) => setState(() => _city = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    MarriageProfile.nativeLanguages.contains(_language)
                    ? _language
                    : MarriageProfile.nativeLanguages.first,
                decoration: const InputDecoration(
                  labelText: 'Language (optional)',
                ),
                items: MarriageProfile.nativeLanguages
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _language = value!),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
