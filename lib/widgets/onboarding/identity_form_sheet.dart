import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../services/form_media_controller.dart';
import '../../services/phone_number.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/dial_code_phone_field.dart';
import '../forms/form_fields.dart';
import '../forms/photo_source_sheet.dart';
import 'otp_sheet.dart';

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
  late final TextEditingController _phone;
  late String _city;
  late String _language;
  late PhoneDialCode _dial;
  final _formKey = GlobalKey<FormState>();

  /// Same upload stack as Marriage / Jobs / … — only Storage folder differs.
  late final FormMediaController _media;
  var _saving = false;
  var _verifying = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<IdentityStore>().identity;
    _name = TextEditingController(text: current.displayName);
    final parts = splitStoredPhone(
      current.whatsappNumber,
      fallback: PhoneDialCode.fromDigits(current.dialCodePreference),
    );
    _dial = parts.dial;
    _phone = TextEditingController(text: parts.national);
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
    _phone.dispose();
    super.dispose();
  }

  Future<bool> _pickPhoto(int slot) async {
    final source = await showPhotoSourceSheet(context, accent: AppColors.rose);
    if (source == null || !mounted) return false;
    return _media.pickAndUploadIdentity(slot: slot, source: source);
  }

  void _removePhoto(int slot) => _media.removeAt(slot);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final store = context.read<IdentityStore>();
      final e164 = toE164Digits(_dial, _phone.text);
      final phoneChanged = e164 != store.identity.whatsappNumber;
      await store.save(
        store.identity.copyWith(
          displayName: _name.text,
          whatsappNumber: e164,
          dialCodePreference: _dial.digits,
          cityId: _city,
          cityLabel: cityLabels[_city] ?? _city,
          nativeLanguage: _language,
          photoUrls: List<String>.from(
            _media.urls.where((url) => url.trim().isNotEmpty),
          ),
          // New number needs a fresh SMS check.
          phoneVerified: phoneChanged ? false : store.identity.phoneVerified,
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

  Future<void> _verifyPhone() async {
    if (_verifying) return;
    // Persist number first so OTP + WhatsApp stay in sync.
    if (_formKey.currentState?.validate() != true) return;
    final store = context.read<IdentityStore>();
    final e164 = toE164Digits(_dial, _phone.text);
    if (e164.isEmpty) return;
    setState(() => _verifying = true);
    try {
      final phoneChanged = e164 != store.identity.whatsappNumber;
      await store.save(
        store.identity.copyWith(
          displayName: _name.text.trim().isEmpty
              ? store.identity.displayName
              : _name.text,
          whatsappNumber: e164,
          dialCodePreference: _dial.digits,
          cityId: _city,
          cityLabel: cityLabels[_city] ?? _city,
          nativeLanguage: _language,
          photoUrls: List<String>.from(
            _media.urls.where((url) => url.trim().isNotEmpty),
          ),
          phoneVerified: phoneChanged ? false : store.identity.phoneVerified,
        ),
      );
      if (!mounted) return;
      final ok = await showOtpSheet(context, preferWhatsAppNumber: true);
      if (!mounted) return;
      setState(() {});
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verified — WhatsApp ready')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = context.watch<IdentityStore>().identity.phoneVerified;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
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
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
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
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              DialCodePhoneField(
                dial: _dial,
                controller: _phone,
                label: 'WhatsApp number',
                onDialChanged: (code) => setState(() => _dial = code),
              ),
              const SizedBox(height: 12),
              _PhoneVerifyBlock(
                verified: verified,
                busy: _verifying,
                onVerify: _verifyPhone,
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
                decoration: const InputDecoration(labelText: 'Native language'),
                items: MarriageProfile.nativeLanguages
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _language = value!),
              ),
              const SizedBox(height: 18),
              FilledButton(
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

/// Google-simple verify status for low-literacy Account users.
class _PhoneVerifyBlock extends StatelessWidget {
  const _PhoneVerifyBlock({
    required this.verified,
    required this.busy,
    required this.onVerify,
  });

  final bool verified;
  final bool busy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (verified) {
      return Material(
        color: AppColors.darkCream,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.verified, color: AppColors.rose, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Phone verified',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify once with an SMS code. Then WhatsApp opens without asking again.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const Key('account_verify_phone'),
          onPressed: busy ? null : onVerify,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sms_outlined),
          label: Text(busy ? 'Opening…' : 'Verify phone (SMS)'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            backgroundColor: AppColors.rose,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
