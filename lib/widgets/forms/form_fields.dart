import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/cities.dart';
import '../../theme/app_theme.dart';

export '../../models/cities.dart' show cityLabels, citiesAz;

class SingleChoiceChips<T> extends StatelessWidget {
  const SingleChoiceChips({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.text,
    super.key,
  });

  final String label;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T value)? text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: values
            .map(
              (value) => ChoiceChip(
                label: Text(text?.call(value) ?? '$value'),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
            )
            .toList(),
      ),
    ],
  );
}

class MultiChoiceChips<T> extends StatelessWidget {
  const MultiChoiceChips({
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<T> values;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: values
            .map(
              (value) => FilterChip(
                label: Text('$value'),
                selected: selected.contains(value),
                onSelected: (checked) {
                  final next = Set<T>.of(selected);
                  checked ? next.add(value) : next.remove(value);
                  onChanged(next);
                },
              ),
            )
            .toList(),
      ),
    ],
  );
}

/// Visual photo slots — tap empty to add, tap filled to replace, ✕ to remove.
class PhotoSlotStrip extends StatelessWidget {
  const PhotoSlotStrip({
    required this.urls,
    required this.minimum,
    required this.maximum,
    required this.accent,
    required this.softAccent,
    required this.onPick,
    required this.onRemove,
    this.previews = const <Uint8List?>[],
    this.busySlot,
    this.uploadProgress,
    this.statusText,
    this.errorText,
    this.motivation =
        'No photo → many people pass.',
    super.key,
  });

  final List<String> urls;
  final List<Uint8List?> previews;
  final int minimum;
  final int maximum;
  final Color accent;
  final Color softAccent;
  final Future<bool> Function(int slot) onPick;
  final ValueChanged<int> onRemove;
  final int? busySlot;
  /// 0.0–1.0 while uploading; null when idle.
  final double? uploadProgress;
  final String? statusText;
  final String? errorText;
  final String motivation;

  @override
  Widget build(BuildContext context) {
    final progress = uploadProgress;
    final progressLabel = progress == null
        ? null
        : 'Uploading… ${(progress.clamp(0.0, 1.0) * 100).round()}%';
    final hint = minimum <= 0
        ? 'Optional — camera or gallery'
        : minimum == maximum
        ? 'Add $minimum — camera or gallery'
        : 'At least $minimum — camera or gallery';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          motivation,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: maximum,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final url = index < urls.length ? urls[index] : null;
              final preview = index < previews.length
                  ? previews[index]
                  : null;
              final filled =
                  (url != null && url.isNotEmpty) || preview != null;
              final required = index < minimum;
              final busy = busySlot == index;
              final filledCount = [
                for (var i = 0; i < maximum; i++)
                  if ((i < urls.length && urls[i].isNotEmpty) ||
                      (i < previews.length && previews[i] != null))
                    i,
              ].length;
              final canEdit =
                  !busy &&
                  busySlot == null &&
                  (filled || index == filledCount);
              return _PhotoSlot(
                url: url,
                previewBytes: preview,
                accent: accent,
                softAccent: softAccent,
                requiredEmpty: required && !filled,
                enabled: canEdit || busy,
                busy: busy,
                onTap: canEdit ? () => onPick(index) : null,
                onRemove: filled && !busy ? () => onRemove(index) : null,
              );
            },
          ),
        ),
        if (progressLabel != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: accent,
              backgroundColor: softAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progressLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ] else if (errorText != null && errorText!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
          ),
        ] else if (statusText != null && statusText!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            statusText!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.url,
    required this.previewBytes,
    required this.accent,
    required this.softAccent,
    required this.requiredEmpty,
    required this.enabled,
    required this.busy,
    this.onTap,
    this.onRemove,
  });

  final String? url;
  final Uint8List? previewBytes;
  final Color accent;
  final Color softAccent;
  final bool requiredEmpty;
  final bool enabled;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final filled =
        previewBytes != null || (url != null && url!.isNotEmpty);
    return Opacity(
      opacity: enabled || filled || busy ? 1 : 0.45,
      child: SizedBox(
        width: 84,
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: softAccent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: requiredEmpty
                            ? accent
                            : accent.withValues(alpha: .35),
                        width: requiredEmpty ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: busy
                          ? Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: accent,
                                ),
                              ),
                            )
                          : filled
                          ? _SlotImage(url: url, previewBytes: previewBytes)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  color: accent,
                                  size: 26,
                                ),
                                if (requiredEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Need',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -4,
                right: -4,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: accent),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotImage extends StatelessWidget {
  const _SlotImage({this.url, this.previewBytes});
  final String? url;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.darkCream,
      child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
    );
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final remote = url ?? '';
    if (remote.startsWith('http://') || remote.startsWith('https://')) {
      return Image.network(
        remote,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (remote.startsWith('local://')) {
      return ColoredBox(
        color: AppColors.darkCream,
        child: Icon(Icons.check_circle_outline, color: AppColors.muted),
      );
    }
    if (remote.isEmpty) return fallback;
    return Image.asset(
      remote,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class CityDropdown extends StatelessWidget {
  const CityDropdown({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = citiesAz;
    final selected = cityLabels.containsKey(value) ? value : items.first.key;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'City'),
      items: items
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
