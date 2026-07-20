import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class BikesForm extends StatefulWidget {
  const BikesForm({
    this.initial,
    this.editIndex,
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
  final BikesOffer? initial;
  final int? editIndex;
  final Future<bool> Function(int slot)? onPickPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final List<String> photoUrls;
  final List<Uint8List?> photoPreviews;
  final int? busySlot;
  final double? uploadProgress;
  final String? photoStatus;
  final String? photoError;
  final Future<void> Function(BikesOffer offer)? onAfterSave;
  final VoidCallback? onSaveSuccess;

  @override
  State<BikesForm> createState() => _BikesFormState();
}

class _BikesFormState extends State<BikesForm> {
  late final TextEditingController _model;
  late final TextEditingController _customRent;
  late String _type;
  late String _transmission;
  late String _make;
  late int _rent;
  late String _city;
  late Set<String> _days;
  late TimeOfDay _from;
  late TimeOfDay _to;

  DomainPolicy get _domain => AppDomains.bikes;

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _model = TextEditingController(text: initial?.model ?? '');
    final hourly = initial?.hourlyRent;
    final inPresets =
        hourly != null && BikesOffer.hourlyRentPresets.contains(hourly);
    _customRent = TextEditingController(
      text: hourly != null && !inPresets ? '$hourly' : '',
    );
    _type = initial?.type ?? BikesOffer.types.first;
    _transmission = initial?.transmission ?? BikesOffer.transmissions.first;
    _make = initial?.make ?? BikesOffer.makes.first;
    _rent = inPresets ? hourly : BikesOffer.hourlyRentPresets.first;
    _city = initial?.cityId ?? 'mumbai';
    _days = {...(initial?.availableWeekdays ?? BikesOffer.weekdays)};
    _from = _parseTime(
      initial?.fromTime ?? '09:00',
      const TimeOfDay(hour: 9, minute: 0),
    );
    _to = _parseTime(
      initial?.toTime ?? '20:00',
      const TimeOfDay(hour: 20, minute: 0),
    );
  }

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
        onPick: (slot) async => await widget.onPickPhoto?.call(slot) ?? false,
        onRemove: (slot) => widget.onRemovePhoto?.call(slot),
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
      photoCount: widget.photoUrls.length,
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
      context.read<BikesOfferStore>().upsert(offer, index: widget.editIndex);
      await widget.onAfterSave?.call(offer);
      if (widget.onSaveSuccess != null) {
        widget.onSaveSuccess!();
      } else {
        navigator.pop();
      }
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    }
  }
}
