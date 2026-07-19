import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class HomeHelpForm extends StatefulWidget {
  const HomeHelpForm({this.onPickPhoto, this.onAfterSave, super.key});
  final Future<bool> Function()? onPickPhoto;
  final Future<void> Function(HomeHelpOffer offer)? onAfterSave;

  @override
  State<HomeHelpForm> createState() => _HomeHelpFormState();
}

class _HomeHelpFormState extends State<HomeHelpForm> {
  String _role = HomeHelpOffer.roles.first;
  String _service = HomeHelpOffer.services.first;
  String _shift = HomeHelpOffer.shifts.first;
  String _salary = HomeHelpOffer.salaryBands.first;
  String _city = 'mumbai';
  Set<String> _languages = {'Hindi'};
  int _photos = 0;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text(
        'Home Help listing',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'I am',
        values: HomeHelpOffer.roles,
        selected: _role,
        text: (v) => v == 'have' ? 'Available for work' : 'Hiring',
        onSelected: (v) => setState(() => _role = v),
      ),
      SingleChoiceChips(
        label: 'Role',
        values: HomeHelpOffer.services,
        selected: _service,
        onSelected: (v) => setState(() => _service = v),
      ),
      SingleChoiceChips(
        label: 'Shift',
        values: HomeHelpOffer.shifts,
        selected: _shift,
        onSelected: (v) => setState(() => _shift = v),
      ),
      SingleChoiceChips(
        label: 'Salary',
        values: HomeHelpOffer.salaryBands,
        selected: _salary,
        onSelected: (v) => setState(() => _salary = v),
      ),
      MultiChoiceChips(
        label: 'Languages',
        values: HomeHelpOffer.languageOptions,
        selected: _languages,
        onChanged: (v) => setState(() => _languages = v),
      ),
      CityDropdown(value: _city, onChanged: (v) => setState(() => _city = v)),
      PhotoCountPicker(
        count: _photos,
        minimum: _role == 'have' ? 1 : 0,
        maximum: 4,
        onPick: widget.onPickPhoto,
        onChanged: (v) => setState(() => _photos = v),
      ),
      FilledButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final offer = HomeHelpOffer(
            role: _role,
            service: _service,
            shift: _shift,
            salaryBand: _salary,
            languages: _languages.toList(),
            photoCount: _photos,
            cityId: _city,
          );
          if (!offer.isValid) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  _role == 'have'
                      ? 'Choose a language and add one photo.'
                      : 'Choose at least one language.',
                ),
              ),
            );
            return;
          }
          try {
            context.read<HomeHelpOfferStore>().upsert(offer);
            await widget.onAfterSave?.call(offer);
            navigator.pop();
          } on StateError catch (error) {
            messenger.showSnackBar(SnackBar(content: Text(error.message)));
          }
        },
        child: const Text('Save listing'),
      ),
    ],
  );
}
