import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
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

  DomainPolicy get _domain => AppDomains.bikes;

  int get _extraFilled {
    var n = 0;
    if (_model.text.trim().isNotEmpty) n++;
    if ((_customRent.text.trim().isNotEmpty) &&
        (int.tryParse(_customRent.text) ?? 0) > 0) {
      n++;
    }
    return n;
  }

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
      Text(
        'Bikes',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: _domain.color,
        ),
      ),
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
      SingleChoiceChips(
        label: 'Hourly rent',
        values: BikesOffer.hourlyRentPresets,
        selected: _rent,
        text: (v) => '₹$v',
        onSelected: (v) => setState(() => _rent = v),
      ),
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
      const SizedBox(height: 12),
      CityDropdown(value: _city, onChanged: (v) => setState(() => _city = v)),
      PhotoCountPicker(
        count: _photos,
        minimum: 4,
        maximum: 4,
        onPick: widget.onPickPhoto,
        onChanged: (v) => setState(() => _photos = v),
      ),
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
            TextField(
              controller: _model,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customRent,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Your price / hour'),
            ),
            const SizedBox(height: 8),
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
