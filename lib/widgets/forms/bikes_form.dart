import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class BikesForm extends StatefulWidget {
  const BikesForm({this.onPickPhoto, this.onAfterSave, super.key});
  final Future<bool> Function()? onPickPhoto;
  final Future<void> Function(BikesOffer offer)? onAfterSave;

  @override
  State<BikesForm> createState() => _BikesFormState();
}

class _BikesFormState extends State<BikesForm> {
  final _model = TextEditingController();
  final _customRent = TextEditingController();
  String _type = BikesOffer.types.first;
  String _transmission = BikesOffer.transmissions.first;
  String _make = BikesOffer.makes.first;
  int _rent = BikesOffer.hourlyRentPresets.first;
  String _city = 'mumbai';
  Set<String> _days = BikesOffer.weekdays.toSet();
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 20, minute: 0);
  int _photos = 0;

  @override
  void dispose() {
    _model.dispose();
    _customRent.dispose();
    super.dispose();
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text('Bike listing', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'Vehicle',
        values: BikesOffer.types,
        selected: _type,
        onSelected: (v) => setState(() => _type = v),
      ),
      SingleChoiceChips(
        label: 'Transmission',
        values: BikesOffer.transmissions,
        selected: _transmission,
        onSelected: (v) => setState(() => _transmission = v),
      ),
      SingleChoiceChips(
        label: 'Make',
        values: BikesOffer.makes,
        selected: _make,
        onSelected: (v) => setState(() => _make = v),
      ),
      TextField(
        controller: _model,
        decoration: const InputDecoration(labelText: 'Model (optional)'),
      ),
      const SizedBox(height: 12),
      SingleChoiceChips(
        label: 'Hourly rent',
        values: BikesOffer.hourlyRentPresets,
        selected: _rent,
        text: (v) => '₹$v',
        onSelected: (v) => setState(() => _rent = v),
      ),
      TextField(
        controller: _customRent,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Custom hourly rent (optional)',
        ),
      ),
      const SizedBox(height: 12),
      MultiChoiceChips(
        label: 'Available days',
        values: BikesOffer.weekdays,
        selected: _days,
        onChanged: (v) => setState(() => _days = v),
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickTime(true),
              child: Text('From ${_time(_from)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickTime(false),
              child: Text('To ${_time(_to)}'),
            ),
          ),
        ],
      ),
      CityDropdown(value: _city, onChanged: (v) => setState(() => _city = v)),
      PhotoCountPicker(
        count: _photos,
        minimum: 4,
        maximum: 4,
        onPick: widget.onPickPhoto,
        onChanged: (v) => setState(() => _photos = v),
      ),
      FilledButton(onPressed: _save, child: const Text('Save listing')),
    ],
  );

  Future<void> _pickTime(bool from) async {
    final value = await showTimePicker(
      context: context,
      initialTime: from ? _from : _to,
    );
    if (value != null) setState(() => from ? _from = value : _to = value);
  }

  Future<void> _save() async {
    final custom = int.tryParse(_customRent.text);
    final offer = BikesOffer(
      type: _type,
      transmission: _transmission,
      make: _make,
      model: _model.text.trim().isEmpty ? null : _model.text.trim(),
      hourlyRent: custom != null && custom > 0 ? custom : _rent,
      cityId: _city,
      availableWeekdays: _days.toList(),
      fromTime: _time(_from),
      toTime: _time(_to),
      photoCount: _photos,
    );
    if (!offer.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select days and add exactly four vehicle photos.'),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      context.read<BikesOfferStore>().upsert(offer);
      await widget.onAfterSave?.call(offer);
      navigator.pop();
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
