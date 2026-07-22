import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/phone_number.dart';
import '../../theme/app_theme.dart';

/// Country dial dropdown + national digits only (Account, WA gate, OTP).
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
    super.key,
  });

  final PhoneDialCode dial;
  final TextEditingController controller;
  final ValueChanged<PhoneDialCode> onDialChanged;
  final String label;
  final bool enabled;
  final bool autofocus;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: DropdownButtonFormField<PhoneDialCode>(
                // ValueKey rebuilds when dial changes (initialValue is one-shot).
                key: ValueKey('dial_code_${dial.digits}'),
                initialValue: dial,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                items: [
                  for (final code in PhoneDialCode.all)
                    DropdownMenuItem(
                      key: Key('dial_${code.digits}'),
                      value: code,
                      child: Text('${code.label} ${code.country}'),
                    ),
                ],
                onChanged: enabled
                    ? (code) {
                        if (code != null) onDialChanged(code);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: controller,
                enabled: enabled,
                autofocus: autofocus,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Phone',
                  hintText: dial == PhoneDialCode.india
                      ? '9869610903'
                      : '90977001',
                ),
                validator:
                    validator ?? (value) => phoneFieldError(dial, value ?? ''),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
