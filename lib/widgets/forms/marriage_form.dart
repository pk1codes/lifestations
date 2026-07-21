import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class MarriageForm extends StatefulWidget {
  const MarriageForm({
    this.initial,
    this.onPickPhoto,
    this.onRemovePhoto,
    this.photoUrls = const <String>[],
    this.photoPreviews = const <Uint8List?>[],
    this.busySlot,
    this.uploadProgress,
    this.photoStatus,
    this.photoError,
    this.onAfterSave,
    this.onSaveSuccess,
    super.key,
  });
  final MarriageProfile? initial;
  final Future<bool> Function(int slot)? onPickPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final List<String> photoUrls;
  final List<Uint8List?> photoPreviews;
  final int? busySlot;
  final double? uploadProgress;
  final String? photoStatus;
  final String? photoError;
  final Future<void> Function(MarriageProfile profile)? onAfterSave;
  /// Called after a successful save instead of popping internally.
  final VoidCallback? onSaveSuccess;

  @override
  State<MarriageForm> createState() => _MarriageFormState();
}

class _MarriageFormState extends State<MarriageForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _age;
  late final TextEditingController _bio;
  late String _gender;
  late String _seeking;
  late String _city;
  String? _salary;
  String? _religion;
  String? _language;
  String? _status;
  int? _height;
  String? _education;
  String? _occupation;
  String? _diet;
  String? _saveMessage;

  DomainPolicy get _domain => AppDomains.marriage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _age = TextEditingController(text: '${initial?.age ?? 25}');
    _bio = TextEditingController(text: initial?.bio ?? '');
    _gender = initial?.gender ?? 'woman';
    _seeking = initial?.seeking ??
        (_gender == 'woman' ? 'man' : (_gender == 'man' ? 'woman' : 'everyone'));
    _city = initial?.cityId ?? 'mumbai';
    _salary = initial?.salaryBand;
    _religion = initial?.religion;
    _language = initial?.nativeLanguage;
    _status = initial?.maritalStatus;
    _height = initial?.heightCm;
    _education = initial?.education;
    _occupation = initial?.occupation;
    _diet = initial?.diet;
  }

  int get _photoCount => widget.photoUrls.length;

  int get _extraFilled => [
    _salary,
    _religion,
    _language,
    _status,
    _height,
    _education,
    _occupation,
    _diet,
  ].where((v) => v != null).length;

  void _onGender(String value) {
    setState(() {
      _gender = value;
      if (value == 'woman') {
        _seeking = 'man';
      } else if (value == 'man') {
        _seeking = 'woman';
      }
    });
  }

  @override
  void dispose() {
    _age.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        Text(
          'Marriage',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: _domain.color,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _age,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Age'),
          validator: (value) {
            final age = int.tryParse(value ?? '');
            return age == null || age < 18 || age > 99
                ? 'Enter age 18–99'
                : null;
          },
        ),
        const SizedBox(height: 12),
        SingleChoiceChips(
          label: 'I am',
          values: MarriageProfile.genders,
          selected: _gender,
          onSelected: _onGender,
        ),
        SingleChoiceChips(
          label: 'Seeking',
          values: MarriageProfile.seekingOptions,
          selected: _seeking,
          onSelected: (value) => setState(() => _seeking = value),
        ),
        CityDropdown(value: _city, onChanged: (v) => setState(() => _city = v)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bio,
          minLines: 2,
          maxLines: 4,
          maxLength: 240,
          decoration: const InputDecoration(labelText: 'Bio'),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            if (length > 240) return 'Too long';
            return null;
          },
        ),
        const SizedBox(height: 8),
        PhotoSlotStrip(
          urls: widget.photoUrls,
          previews: widget.photoPreviews,
          minimum: _domain.minPhotos,
          maximum: _domain.maxPhotos,
          accent: _domain.color,
          softAccent: _domain.softColor,
          busySlot: widget.busySlot,
          uploadProgress: widget.uploadProgress,
          statusText: widget.photoStatus,
          errorText: widget.photoError,
          onPick: (slot) async =>
              await widget.onPickPhoto?.call(slot) ?? false,
          onRemove: (slot) => widget.onRemovePhoto?.call(slot),
        ),
        if (_saveMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _saveMessage!,
            style: TextStyle(
              color: _domain.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            leading: CircleAvatar(
              backgroundColor: _domain.softColor,
              child: Icon(Icons.add, color: _domain.color),
            ),
            title: Text(
              'More',
              style: TextStyle(
                color: _domain.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: _extraFilled == 0
                ? null
                : CircleAvatar(
                    radius: 12,
                    backgroundColor: _domain.softColor,
                    child: Text(
                      '$_extraFilled',
                      style: TextStyle(
                        color: _domain.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            children: [
              _extra(
                'Salary',
                MarriageProfile.salaryBands,
                _salary,
                (v) => _salary = v,
              ),
              _extra(
                'Religion',
                MarriageProfile.religions,
                _religion,
                (v) => _religion = v,
              ),
              _extra(
                'Language',
                MarriageProfile.nativeLanguages,
                _language,
                (v) => _language = v,
              ),
              _extra(
                'Status',
                MarriageProfile.maritalStatuses,
                _status,
                (v) => _status = v,
              ),
              _extra(
                'Height',
                MarriageProfile.heightsCm,
                _height,
                (v) => _height = v,
              ),
              _extra(
                'Education',
                MarriageProfile.educationOptions,
                _education,
                (v) => _education = v,
              ),
              _extra(
                'Work',
                MarriageProfile.occupations,
                _occupation,
                (v) => _occupation = v,
              ),
              _extra('Diet', MarriageProfile.diets, _diet, (v) => _diet = v),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _domain.color),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );

  Widget _extra<T>(
    String label,
    List<T> values,
    T? value,
    ValueChanged<T?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text('$item')))
          .toList(),
      onChanged: (next) => setState(() => changed(next)),
    ),
  );

  Future<void> _save() async {
    setState(() => _saveMessage = null);
    if (!_key.currentState!.validate()) return;
    final profile = MarriageProfile(
      age: int.parse(_age.text),
      gender: _gender,
      seeking: _seeking,
      bio: _bio.text.trim(),
      cityId: _city,
      photoCount: _photoCount,
      salaryBand: _salary,
      religion: _religion,
      nativeLanguage: _language,
      maritalStatus: _status,
      heightCm: _height,
      education: _education,
      occupation: _occupation,
      diet: _diet,
    );
    if (!profile.isValid) {
      setState(() => _saveMessage = 'Add a photo.');
      return;
    }
    if (widget.photoUrls.isEmpty) {
      setState(
        () => _saveMessage =
            'Photo not uploaded yet. Wait for “Photo added” then Save.',
      );
      return;
    }
    final store = context.read<ProfileStore>();
    try {
      setState(() => _saveMessage = 'Saving…');
      store.saveLocal(profile);
      final ok = await store.synchronize((value) async {
        await widget.onAfterSave?.call(value);
      });
      if (!ok) {
        setState(
          () => _saveMessage = store.syncError ?? 'Could not save. Try again.',
        );
        return;
      }
      if (widget.onSaveSuccess != null) {
        widget.onSaveSuccess!();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      setState(() => _saveMessage = 'Could not save. Try again.');
    }
  }
}
