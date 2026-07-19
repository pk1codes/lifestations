import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class JobsForm extends StatefulWidget {
  const JobsForm({this.onPickPhoto, this.onAfterSave, super.key});
  final Future<bool> Function()? onPickPhoto;
  final Future<void> Function(JobsProfile profile)? onAfterSave;

  @override
  State<JobsForm> createState() => _JobsFormState();
}

class _JobsFormState extends State<JobsForm> {
  String _role = 'seek';
  String _trade = JobsProfile.trades.first;
  String _salary = JobsProfile.salaryBands.first;
  String _city = 'mumbai';
  int _photos = 0;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text('Jobs profile', style: Theme.of(context).textTheme.headlineMedium),
      const Text('Build a clear need line without writing a biography.'),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'I want to',
        values: const ['seek', 'offer'],
        selected: _role,
        onSelected: (v) => setState(() => _role = v),
      ),
      SingleChoiceChips(
        label: 'Trade',
        values: JobsProfile.trades,
        selected: _trade,
        onSelected: (v) => setState(() => _trade = v),
      ),
      SingleChoiceChips(
        label: 'Monthly salary',
        values: JobsProfile.salaryBands,
        selected: _salary,
        onSelected: (v) => setState(() => _salary = v),
      ),
      CityDropdown(value: _city, onChanged: (v) => setState(() => _city = v)),
      const SizedBox(height: 12),
      Text(
        _role == 'seek' ? 'Looking for $_trade work' : 'Need $_trade help',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      PhotoCountPicker(
        count: _photos,
        minimum: 1,
        maximum: 3,
        onPick: widget.onPickPhoto,
        onChanged: (v) => setState(() => _photos = v),
      ),
      FilledButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          if (_photos < 1) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Add at least one clear portrait.')),
            );
            return;
          }
          final profile = JobsProfile(
            role: _role,
            tradeId: _trade,
            cityId: _city,
            salaryBand: _salary,
          );
          final store = context.read<JobsProfileStore>();
          store.saveLocal(profile);
          await store.synchronize((value) async {
            await widget.onAfterSave?.call(value);
          });
          navigator.pop();
        },
        child: const Text('Save profile'),
      ),
    ],
  );
}
