import 'package:flutter/material.dart';

/// Shared Save affordance: disabled until [missing] is empty, with an inline list.
class SaveGateButton extends StatelessWidget {
  const SaveGateButton({
    required this.missing,
    required this.onSave,
    required this.accent,
    this.busy = false,
    this.label = 'Save',
    super.key,
  });

  final List<String> missing;
  final VoidCallback? onSave;
  final Color accent;
  final bool busy;
  final String label;

  bool get canSave => missing.isEmpty && !busy && onSave != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missing.isNotEmpty) ...[
          Text(
            missing.join(' · '),
            key: const Key('save_missing'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton(
          key: const Key('save_gate_button'),
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: canSave ? onSave : null,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      ],
    );
  }
}

String photosNeededLabel({required int have, required int need}) {
  if (have >= need) return '';
  final left = need - have;
  if (need == 1) return 'Add a photo';
  if (have == 0) return 'Add $need photos';
  return 'Add $left more photo${left == 1 ? '' : 's'}';
}
