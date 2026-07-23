import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/phone_number.dart';
import '../../theme/app_theme.dart';

/// Country dial chips (+91 / +965) + national digits only (Account, WA gate, OTP).
/// Default dial is India (+91); user never types the country code.
class DialCodePhoneField extends StatelessWidget {
  const DialCodePhoneField({
    required this.dial,
    required this.controller,
    required this.onDialChanged,
    this.label = 'Number',
    this.enabled = true,
    this.autofocus = false,
    this.validator,
    this.onComplete,
    super.key,
  });

  final PhoneDialCode dial;
  final TextEditingController controller;
  final ValueChanged<PhoneDialCode> onDialChanged;
  final String label;
  final bool enabled;
  final bool autofocus;
  final FormFieldValidator<String>? validator;

  /// Fires once the national field reaches the expected digit count.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final maxLen = nationalLengthHint(dial);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in PhoneDialCode.all)
              ChoiceChip(
                key: Key('dial_${code.digits}'),
                label: Text(code.label),
                selected: dial == code,
                onSelected: enabled
                    ? (selected) {
                        if (selected) onDialChanged(code);
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${dial.country} ${dial.label}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLen),
          ],
          decoration: InputDecoration(
            labelText: 'Phone',
            hintText: nationalHintExample(dial),
          ),
          validator: validator ?? (value) => phoneFieldError(dial, value ?? ''),
          onChanged: enabled && onComplete != null
              ? (value) {
                  if (cleanNational(value).length == maxLen) {
                    onComplete!();
                  }
                }
              : null,
        ),
      ],
    );
  }
}
