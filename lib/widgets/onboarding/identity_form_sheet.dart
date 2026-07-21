import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../services/form_media_controller.dart';
import '../../state/app_stores.dart';
import '../../theme/app_theme.dart';
import '../forms/form_fields.dart';
import '../forms/photo_source_sheet.dart';

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
  final _formKey = GlobalKey<FormState>();
  /// Same upload stack as Marriage / Jobs / … — only Storage folder differs.
  late final FormMediaController _media;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<IdentityStore>().identity;
    _name = TextEditingController(text: current.displayName);
    _phone = TextEditingController(text: current.whatsappNumber);
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
      const labels = {
        'mumbai': 'Mumbai & MMR',
        'delhi': 'Delhi NCR',
        'bengaluru': 'Bengaluru',
      };
      final store = context.read<IdentityStore>();
      await store.save(
        store.identity.copyWith(
          displayName: _name.text,
          whatsappNumber: _phone.text,
          cityId: _city,
          cityLabel: labels[_city],
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
                'My details',
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
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number',
                ),
                validator: (value) {
                  final digits =
                      (value ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 8) return 'Enter at least 8 digits';
                  if (digits.length > 15) return 'Use at most 15 digits';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(labelText: 'City'),
                items: const [
                  DropdownMenuItem(
                    value: 'mumbai',
                    child: Text('Mumbai & MMR'),
                  ),
                  DropdownMenuItem(value: 'delhi', child: Text('Delhi NCR')),
                  DropdownMenuItem(
                    value: 'bengaluru',
                    child: Text('Bengaluru'),
                  ),
                ],
                onChanged: (value) => setState(() => _city = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(
                  labelText: 'Native language',
                ),
                items:
                    const [
                          'Hindi',
                          'English',
                          'Marathi',
                          'Tamil',
                          'Telugu',
                          'Kannada',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
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
