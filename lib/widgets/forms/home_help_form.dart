import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';
import 'save_gate.dart';

class HomeHelpForm extends StatefulWidget {
  const HomeHelpForm({
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
  final HomeHelpOffer? initial;
  final int? editIndex;
  final Future<bool> Function(int slot)? onPickPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final List<String> photoUrls;
  final List<Uint8List?> photoPreviews;
  final int? busySlot;
  final double? uploadProgress;
  final String? photoStatus;
  final String? photoError;
  final Future<void> Function(HomeHelpOffer offer)? onAfterSave;
  final VoidCallback? onSaveSuccess;

  @override
  State<HomeHelpForm> createState() => _HomeHelpFormState();
}

class _HomeHelpFormState extends State<HomeHelpForm> {
  late String _role;
  late String _service;
  late String _shift;
  late String _salary;
  late String _city;
  late String _howMany;
  late Set<String> _languages;

  DomainPolicy get _domain => AppDomains.homeHelp;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _role = initial?.role ?? HomeHelpOffer.roles.first;
    _service = initial?.service ?? HomeHelpOffer.services.first;
    _shift = initial?.shift ?? HomeHelpOffer.shifts.first;
    _salary = initial?.salaryBand ?? HomeHelpOffer.salaryBands.first;
    _city = initial?.cityId ?? 'mumbai';
    _howMany = initial?.howMany ?? HomeHelpOffer.howManyOptions.first;
    _languages = {
      ...(initial?.languages ?? const <String>['Hindi']),
    };
  }

  bool get _isDemand => _role == 'need';
  int get _minPhotos => _isDemand ? 0 : 1;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text(
        'Home Help',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: _domain.color),
      ),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'Looking for',
        values: HomeHelpOffer.roles,
        selected: _role,
        text: (v) => v == 'have' ? 'I have' : 'I need',
        onSelected: (v) => setState(() => _role = v),
      ),
      SingleChoiceChips(
        label: 'Role',
        values: HomeHelpOffer.services,
        selected: _service,
        onSelected: (v) => setState(() => _service = v),
      ),
      if (_isDemand)
        SingleChoiceChips(
          label: 'How many',
          values: HomeHelpOffer.howManyOptions,
          selected: _howMany,
          onSelected: (v) => setState(() => _howMany = v),
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
      const SizedBox(height: 8),
      PhotoSlotStrip(
        urls: widget.photoUrls,
        previews: widget.photoPreviews,
        minimum: _minPhotos,
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
      SaveGateButton(
        missing: [
          if (_role == 'have')
            photosNeededLabel(have: widget.photoUrls.length, need: _minPhotos),
          if (_languages.isEmpty) 'Choose a language',
        ].where((s) => s.isNotEmpty).toList(growable: false),
        accent: _domain.color,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final offer = HomeHelpOffer(
            role: _role,
            service: _service,
            shift: _shift,
            salaryBand: _salary,
            languages: _languages.toList(),
            photoCount: widget.photoUrls.length,
            cityId: _city,
            howMany: _isDemand ? _howMany : null,
          );
          if (!offer.isValid) return;
          try {
            await context.read<HomeHelpOfferStore>().synchronizeUpsert(
              offer,
              index: widget.editIndex,
              write: (value) async {
                await widget.onAfterSave?.call(value);
              },
            );
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
      ),
    ],
  );
}
