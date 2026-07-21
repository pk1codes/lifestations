import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../models/domain_profiles.dart';
import '../../state/domain_profile_stores.dart';
import 'form_fields.dart';

class JobsForm extends StatefulWidget {
  const JobsForm({
    this.initial,
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

  DomainPolicy get _domain => AppDomains.jobs;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _role = initial?.role ?? 'seek';
    _trade = initial?.tradeId ?? JobsProfile.trades.first;
    _salary = initial?.salaryBand ?? JobsProfile.salaryBands.first;
    _city = initial?.cityId ?? 'mumbai';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    children: [
      Text(
        'Jobs',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: _domain.color,
        ),
      ),
      const SizedBox(height: 16),
      SingleChoiceChips(
        label: 'Looking for',
        values: const ['seek', 'offer'],
        selected: _role,
        text: (v) => v == 'seek' ? 'I have' : 'I need',
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
          if (widget.photoUrls.length < _domain.minPhotos) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Add a photo.')),
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
          final ok = await store.synchronize((value) async {
            await widget.onAfterSave?.call(value);
          });
          if (!ok) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(store.syncError ?? 'Could not save. Try again.'),
              ),
            );
            return;
          }
          if (widget.onSaveSuccess != null) {
            widget.onSaveSuccess!();
          } else {
            navigator.pop();
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
