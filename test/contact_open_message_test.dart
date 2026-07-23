import 'package:flut_marriage/services/contact_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contactOpenMessage includes domain when provided', () {
    expect(
      contactOpenMessage(domainLabel: 'Jobs'),
      'Hi, I found you on Life Stations (Jobs).',
    );
    expect(
      contactOpenMessage(),
      'Hi, I found you on Life Stations.',
    );
  });

  test('WhatsApp URI prefills phone and message', () {
    final msg = contactOpenMessage(domainLabel: 'Marriage');
    final https = buildWhatsAppHttpsUri('919869610903', message: msg);
    expect(https.scheme, 'https');
    expect(https.host, 'wa.me');
    expect(https.path, '/919869610903');
    expect(https.queryParameters['text'], msg);

    final api = buildWhatsAppApiUri('919869610903', message: msg);
    expect(api.host, 'api.whatsapp.com');
    expect(api.queryParameters['phone'], '919869610903');
    expect(api.queryParameters['text'], msg);

    final native = buildWhatsAppNativeUri('+91 98696 10903', message: msg);
    expect(native.scheme, 'whatsapp');
    expect(native.queryParameters['phone'], '919869610903');
    expect(native.queryParameters['text'], msg);
  });

  test('Telegram URI opens handle in app or t.me', () {
    final native = buildTelegramNativeUri('@some_user');
    expect(native.scheme, 'tg');
    expect(native.queryParameters['domain'], 'some_user');

    final https = buildTelegramHttpsUri('@some_user');
    expect(https.toString(), 'https://t.me/some_user');
  });

  test('openWhatsApp digit gate (≥8)', () {
    expect(cleanWhatsAppDigits('1234567').length >= 8, isFalse);
    expect(cleanWhatsAppDigits('+91 98765 43210').length >= 8, isTrue);
  });
}
