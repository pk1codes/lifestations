import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class MarriageForm extends StatefulWidget {
  const MarriageForm({
    this.onPickPhoto,
    this.photoUrls = const <String>[],
    this.onAfterSave,
    super.key,
  });
  final Future<bool> Function()? onPickPhoto;
  final List<String> photoUrls;
  final Future<void> Function(MarriageProfile profile)? onAfterSave;

  @override
  State<MarriageForm> createState() => _MarriageFormState();
}

class _MarriageFormState extends State<MarriageForm> {
  final _key = GlobalKey<FormState>();
  final _age = TextEditingController(text: '25');
  final _bio = TextEditingController();
  String _gender = MarriageProfile.genders.first;
  String _seeking = MarriageProfile.seekingOptions.first;
  String _city = 'mumbai';
  int _photos = 0;
  String? _salary;
  String? _religion;
  String? _language;
  String? _status;
  int? _height;
  String? _education;
  String? _occupation;
  String? _diet;

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
          'Marriage profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text('Required basics first. Optional details are tap-to-pick.'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _age,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Age'),
          validator: (value) {
            final age = int.tryParse(value ?? '');
            return age == null || age < 18 || age > 99
                ? 'Enter an age from 18 to 99'
                : null;
          },
        ),
        const SizedBox(height: 12),
        SingleChoiceChips(
          label: 'I am',
          values: MarriageProfile.genders,
          selected: _gender,
          onSelected: (value) => setState(() => _gender = value),
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
          decoration: const InputDecoration(labelText: 'Short bio'),
          validator: (value) => (value?.trim().length ?? 0) < 10
              ? 'Write at least 10 characters'
              : null,
        ),
        _optional(
          'Salary band',
          MarriageProfile.salaryBands,
          _salary,
          (v) => _salary = v,
        ),
        _optional(
          'Religion',
          MarriageProfile.religions,
          _religion,
          (v) => _religion = v,
        ),
        _optional(
          'Native language',
          MarriageProfile.nativeLanguages,
          _language,
          (v) => _language = v,
        ),
        _optional(
          'Marital status',
          MarriageProfile.maritalStatuses,
          _status,
          (v) => _status = v,
        ),
        _optional(
          'Height',
          MarriageProfile.heightsCm,
          _height,
          (v) => _height = v,
        ),
        _optional(
          'Education',
          MarriageProfile.educationOptions,
          _education,
          (v) => _education = v,
        ),
        _optional(
          'Occupation',
          MarriageProfile.occupations,
          _occupation,
          (v) => _occupation = v,
        ),
        _optional('Diet', MarriageProfile.diets, _diet, (v) => _diet = v),
        PhotoCountPicker(
          count: _photos,
          minimum: 1,
          maximum: 3,
          onPick: widget.onPickPhoto,
          onChanged: (value) => setState(() => _photos = value),
        ),
        FilledButton(onPressed: _save, child: const Text('Save profile')),
      ],
    ),
  );

  Widget _optional<T>(
    String label,
    List<T> values,
    T? value,
    ValueChanged<T?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: '$label (optional)'),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text('$item')))
          .toList(),
      onChanged: (next) => setState(() => changed(next)),
    ),
  );

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final profile = MarriageProfile(
      age: int.parse(_age.text),
      gender: _gender,
      seeking: _seeking,
      bio: _bio.text.trim(),
      cityId: _city,
      photoCount: _photos,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one clear portrait.')),
      );
      return;
    }
    final store = context.read<ProfileStore>();
    final navigator = Navigator.of(context);
    store.saveLocal(profile);
    await store.synchronize((value) async {
      await widget.onAfterSave?.call(value);
    });
    navigator.pop();
  }
}
