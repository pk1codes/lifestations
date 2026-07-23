import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared Save affordance: disabled until [missing] is empty, with an inline list.
///
/// On tap, immediately shows a Google-style busy state (spinner + “Saving…”)
/// so the press is obvious while the async save runs — used by every domain form.
class SaveGateButton extends StatefulWidget {
  const SaveGateButton({
    required this.missing,
    required this.onSave,
    required this.accent,
    this.busy = false,
    this.label = 'Save',
    super.key,
  });

  final List<String> missing;

  /// Async save. The button awaits this and owns tap feedback.
  final Future<void> Function()? onSave;
  final Color accent;

  /// Extra busy from the parent (e.g. Marriage form’s own `_saving` flag).
  final bool busy;
  final String label;

  @override
  State<SaveGateButton> createState() => _SaveGateButtonState();
}

class _SaveGateButtonState extends State<SaveGateButton> {
  var _pending = false;

  bool get _busy => _pending || widget.busy;

  bool get canSave =>
      widget.missing.isEmpty && !_busy && widget.onSave != null;

  Future<void> _onPressed() async {
    final save = widget.onSave;
    if (!canSave || save == null) return;
    setState(() => _pending = true);
    try {
      await save();
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.missing.isNotEmpty) ...[
          Text(
            widget.missing.join(' · '),
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
          style: FilledButton.styleFrom(
            backgroundColor: widget.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: widget.accent.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size(48, 52),
          ).copyWith(overlayColor: AppTapFeedback.overlayColor()),
          onPressed: busy
              ? () {}
              : (canSave ? _onPressed : null),
          child: busy
              ? const Row(
                  key: Key('save_gate_busy'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Saving…'),
                  ],
                )
              : Text(widget.label),
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
