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

  test('gate copy matches Browse like vs Liked-me like-back', () {
    expect(whatsAppGateTitle(WhatsAppGatePurpose.like), 'Add WhatsApp to like');
    expect(whatsAppGateCta(WhatsAppGatePurpose.like), 'Save & like');
    expect(
      whatsAppGateTitle(WhatsAppGatePurpose.likeBack),
      'Add WhatsApp to accept',
    );
    expect(whatsAppGateCta(WhatsAppGatePurpose.likeBack), 'Save & accept');
    expect(
      whatsAppGateBody(WhatsAppGatePurpose.like),
      contains('Add your number so matches can reach you'),
    );
    expect(
      whatsAppGateBody(WhatsAppGatePurpose.likeBack),
      contains('Add your number to accept'),
    );
  });

  test('contact-share gate is WhatsApp-only number copy', () {
    expect(
      whatsAppGateTitle(WhatsAppGatePurpose.contactShare),
      'WhatsApp for chat',
    );
    expect(whatsAppGateCta(WhatsAppGatePurpose.contactShare), 'Save number');
    expect(
      whatsAppGateBody(WhatsAppGatePurpose.contactShare),
      contains('WhatsApp only'),
    );
  });
}
