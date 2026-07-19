import 'package:flutter/material.dart';

const cityLabels = <String, String>{
  'mumbai': 'Mumbai & MMR',
  'delhi': 'Delhi NCR',
  'bengaluru': 'Bengaluru',
};

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

class PhotoCountPicker extends StatelessWidget {
  const PhotoCountPicker({
    required this.count,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    this.onPick,
    super.key,
  });

  final int count;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;
  final Future<bool> Function()? onPick;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.photo_library_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('$count / $maximum photos (minimum $minimum)')),
          IconButton(
            tooltip: 'Remove photo',
            onPressed: count == 0 ? null : () => onChanged(count - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: 'Add photo',
            onPressed: count >= maximum
                ? null
                : () async {
                    final ok = onPick == null ? true : await onPick!();
                    if (ok) onChanged(count + 1);
                  },
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
    ),
  );
}

class CityDropdown extends StatelessWidget {
  const CityDropdown({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: const InputDecoration(labelText: 'City'),
    items: cityLabels.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(),
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}
