import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';
import 'save_gate.dart';

class KuwaitJobsForm extends StatefulWidget {
  const KuwaitJobsForm({
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
  final KuwaitJobsProfile? initial;
  final int? editIndex;
  final Future<bool> Function(int slot)? onPickPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final List<String> photoUrls;
  final List<Uint8List?> photoPreviews;
  final int? busySlot;
  final double? uploadProgress;
  final String? photoStatus;
  final String? photoError;
  final Future<void> Function(KuwaitJobsProfile profile)? onAfterSave;
  final VoidCallback? onSaveSuccess;

  @override
  State<KuwaitJobsForm> createState() => _KuwaitJobsFormState();
}

class _KuwaitJobsFormState extends State<KuwaitJobsForm> {
  late String _role;
  late String _trade;
  late String _country;
  late String _salary;
  late String _nationality;
  late String _experience;
  late String _howMany;

  DomainPolicy get _domain => AppDomains.kuwaitJobs;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _role = initial?.role ?? 'seek';
    _trade = initial?.tradeId ?? KuwaitJobsProfile.trades.first;
    _country = initial?.countryId ?? 'kuwait';
    _salary =
        initial?.salaryBand ?? KuwaitJobsProfile.salaryBandsFor(_country).first;
    _nationality = initial?.nationality ?? KuwaitJobsProfile.nationalities.first;
    _experience =
        initial?.experienceBand ?? KuwaitJobsProfile.experienceBands.first;
    _howMany = initial?.howMany ?? KuwaitJobsProfile.howManyOptions.first;
  }

  bool get _isDemand => _role == 'offer';
  int get _minPhotos => _isDemand ? 0 : 1;

  void _onCountryChanged(String country) {
    setState(() {
      _country = country;
      final bands = KuwaitJobsProfile.salaryBandsFor(country);
      if (!bands.contains(_salary)) {
        _salary = bands.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text(
        'Kuwait Jobs',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: _domain.color),
      ),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'Looking for',
        values: KuwaitJobsProfile.roles,
        selected: _role,
        text: KuwaitJobsProfile.roleLabel,
        onSelected: (v) => setState(() => _role = v),
      ),
      SingleChoiceChips(
        label: 'Country',
        values: KuwaitJobsProfile.countryIds,
        selected: _country,
        text: (id) => KuwaitJobsProfile.countryLabels[id] ?? id,
        onSelected: _onCountryChanged,
      ),
      SingleChoiceChips(
        label: 'Position',
        values: KuwaitJobsProfile.trades,
        selected: _trade,
        onSelected: (v) => setState(() => _trade = v),
      ),
      if (_isDemand)
        SingleChoiceChips(
          label: 'How many',
          values: KuwaitJobsProfile.howManyOptions,
          selected: _howMany,
          onSelected: (v) => setState(() => _howMany = v),
        ),
      SingleChoiceChips(
        label: 'Nationality',
        values: KuwaitJobsProfile.nationalities,
        selected: _nationality,
        onSelected: (v) => setState(() => _nationality = v),
      ),
      SingleChoiceChips(
        label: 'Experience (years)',
        values: KuwaitJobsProfile.experienceBands,
        selected: _experience,
        onSelected: (v) => setState(() => _experience = v),
      ),
      SingleChoiceChips(
        label: 'Monthly salary',
        values: KuwaitJobsProfile.salaryBandsFor(_country),
        selected: _salary,
        onSelected: (v) => setState(() => _salary = v),
      ),
      const SizedBox(height: 12),
      Text(_trade, style: Theme.of(context).textTheme.titleMedium),
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
          if (!_isDemand)
            photosNeededLabel(have: widget.photoUrls.length, need: _minPhotos),
        ].where((s) => s.isNotEmpty).toList(growable: false),
        accent: _domain.color,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final profile = KuwaitJobsProfile(
            role: _role,
            tradeId: _trade,
            countryId: _country,
            salaryBand: _salary,
            nationality: _nationality,
            experienceBand: _experience,
            photoCount: widget.photoUrls.length,
            howMany: _isDemand ? _howMany : null,
          );
          if (!profile.isValid) return;
          try {
            await context.read<KuwaitJobsOfferStore>().synchronizeUpsert(
              profile,
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
