import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';
import 'save_gate.dart';

class JobsForm extends StatefulWidget {
  const JobsForm({
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
  final JobsProfile? initial;
  final int? editIndex;
  final Future<bool> Function(int slot)? onPickPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final List<String> photoUrls;
  final List<Uint8List?> photoPreviews;
  final int? busySlot;
  final double? uploadProgress;
  final String? photoStatus;
  final String? photoError;
  final Future<void> Function(JobsProfile profile)? onAfterSave;
  final VoidCallback? onSaveSuccess;

  @override
  State<JobsForm> createState() => _JobsFormState();
}

class _JobsFormState extends State<JobsForm> {
  late String _role;
  late String _trade;
  late String _salary;
  late String _city;
  late String _howMany;

  DomainPolicy get _domain => AppDomains.jobs;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _role = initial?.role ?? 'seek';
    _trade = initial?.tradeId ?? JobsProfile.trades.first;
    _salary = initial?.salaryBand ?? JobsProfile.salaryBands.first;
    _city = initial?.cityId ?? 'mumbai';
    _howMany = initial?.howMany ?? JobsProfile.howManyOptions.first;
  }

  bool get _isDemand => _role == 'offer';
  int get _minPhotos => _isDemand ? 0 : 1;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text(
        'Jobs',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: _domain.color),
      ),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'Looking for',
        values: JobsProfile.roles,
        selected: _role,
        text: JobsProfile.roleLabel,
        onSelected: (v) => setState(() => _role = v),
      ),
      SingleChoiceChips(
        label: 'Trade',
        values: JobsProfile.trades,
        selected: _trade,
        onSelected: (v) => setState(() => _trade = v),
      ),
      if (_isDemand)
        SingleChoiceChips(
          label: 'How many',
          values: JobsProfile.howManyOptions,
          selected: _howMany,
          onSelected: (v) => setState(() => _howMany = v),
        ),
      SingleChoiceChips(
        label: 'Monthly salary',
        values: JobsProfile.salaryBands,
        selected: _salary,
        onSelected: (v) => setState(() => _salary = v),
      ),
      CityDropdown(value: _city, onChanged: (v) => setState(() => _city = v)),
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
          final profile = JobsProfile(
            role: _role,
            tradeId: _trade,
            cityId: _city,
            salaryBand: _salary,
            photoCount: widget.photoUrls.length,
            howMany: _isDemand ? _howMany : null,
          );
          if (!profile.isValid) return;
          try {
            await context.read<JobsOfferStore>().synchronizeUpsert(
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
