import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/widgets/onboarding/whatsapp_gate_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasWhatsAppNumber requires at least 8 digits', () {
    expect(hasWhatsAppNumber(const Identity()), isFalse);
    expect(
      hasWhatsAppNumber(const Identity(whatsappNumber: '1234567')),
      isFalse,
    );
    expect(
      hasWhatsAppNumber(const Identity(whatsappNumber: '+91 98765 43210')),
      isTrue,
    );
  });
}
