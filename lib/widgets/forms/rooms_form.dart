import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class RoomsForm extends StatefulWidget {
  const RoomsForm({
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
  final RoomsOffer? initial;
  final int? editIndex;
  final Future<bool> Function(int slot)? onPickPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final List<String> photoUrls;
  final List<Uint8List?> photoPreviews;
  final int? busySlot;
  final double? uploadProgress;
  final String? photoStatus;
  final String? photoError;
  final Future<void> Function(RoomsOffer offer)? onAfterSave;
  final VoidCallback? onSaveSuccess;

  @override
  State<RoomsForm> createState() => _RoomsFormState();
}

class _RoomsFormState extends State<RoomsForm> {
  late String _type;
  late String _furnishing;
  late int _rent;
  late int _deposit;
  late String _city;
  late Set<String> _amenities;

  DomainPolicy get _domain => AppDomains.rooms;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type ?? RoomsOffer.types.first;
    _furnishing = initial?.furnishing ?? RoomsOffer.furnishingOptions.first;
    final rent = initial?.monthlyRent;
    _rent = rent != null && RoomsOffer.rentPresets.contains(rent)
        ? rent
        : RoomsOffer.rentPresets.first;
    _deposit = initial?.depositMonths ?? 0;
    _city = initial?.cityId ?? 'mumbai';
    _amenities = {...?initial?.amenities};
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text(
        'Rooms',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: _domain.color,
        ),
      ),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'Type',
        values: RoomsOffer.types,
        selected: _type,
        onSelected: (v) => setState(() => _type = v),
      ),
      SingleChoiceChips(
        label: 'Furnishing',
        values: RoomsOffer.furnishingOptions,
        selected: _furnishing,
        onSelected: (v) => setState(() => _furnishing = v),
      ),
      SingleChoiceChips(
        label: 'Monthly rent',
        values: RoomsOffer.rentPresets,
        selected: _rent,
        text: (v) => '₹${v ~/ 1000}k',
        onSelected: (v) => setState(() => _rent = v),
      ),
      SingleChoiceChips(
        label: 'Deposit',
        values: RoomsOffer.depositOptions,
        selected: _deposit,
        text: (v) => v == 0 ? 'None' : '$v month${v == 1 ? '' : 's'}',
        onSelected: (v) => setState(() => _deposit = v),
      ),
      MultiChoiceChips(
        label: 'Amenities',
        values: RoomsOffer.amenityOptions,
        selected: _amenities,
        onChanged: (v) => setState(() => _amenities = v),
      ),
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
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _domain.color),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final offer = RoomsOffer(
            type: _type,
            furnishing: _furnishing,
            monthlyRent: _rent,
            depositMonths: _deposit,
            cityId: _city,
            photoCount: widget.photoUrls.length,
            amenities: _amenities.toList(),
          );
          if (!offer.isValid) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Add 2 photos.')),
            );
            return;
          }
          try {
            context.read<RoomsOfferStore>().upsert(
              offer,
              index: widget.editIndex,
            );
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
        },
        child: const Text('Save'),
      ),
    ],
  );
}
