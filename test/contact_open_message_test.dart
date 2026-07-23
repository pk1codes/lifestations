import 'package:cloud_functions/cloud_functions.dart';
import 'package:flut_marriage/services/contact_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contactOpenMessage includes domain when provided', () {
    expect(
      contactOpenMessage(domainLabel: 'Jobs'),
      'Hi, I found you on Life Stations (Jobs).',
    );
    expect(contactOpenMessage(), 'Hi, I found you on Life Stations.');
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

  test('Telegram username URI can prefill draft text', () {
    final msg = contactOpenMessage(domainLabel: 'Jobs');
    final native = buildTelegramNativeUri('@some_user', message: msg);
    expect(native.scheme, 'tg');
    expect(native.queryParameters['domain'], 'some_user');
    expect(native.queryParameters['text'], msg);

    final https = buildTelegramHttpsUri('@some_user', message: msg);
    expect(https.host, 't.me');
    expect(https.path, '/some_user');
    expect(https.queryParameters['text'], msg);
  });

  test('Telegram phone URI opens chat with draft text', () {
    final msg = contactOpenMessage(domainLabel: 'Kuwait Jobs');
    final native = buildTelegramPhoneNativeUri('+965 1234 5678', message: msg);
    expect(native.scheme, 'tg');
    expect(native.queryParameters['phone'], '96512345678');
    expect(native.queryParameters['text'], msg);

    final https = buildTelegramPhoneHttpsUri('96512345678', message: msg);
    expect(https.host, 't.me');
    expect(https.path, '/+96512345678');
    expect(https.queryParameters['text'], msg);
  });

  test('openWhatsApp digit gate (≥8)', () {
    expect(cleanWhatsAppDigits('1234567').length >= 8, isFalse);
    expect(cleanWhatsAppDigits('+91 98765 43210').length >= 8, isTrue);
  });

  test('unlock error maps App Check / unauthenticated honestly', () {
    expect(
      ContactService.friendlyUnlockError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'App Check token missing',
        ),
      ),
      contains('Play app verification'),
    );
    expect(
      ContactService.friendlyUnlockError(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Sign in required.',
        ),
      ),
      'Sign in required',
    );
    expect(
      ContactService.friendlyUnlockError(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Mutual interest required.',
        ),
      ),
      'Mutual interest required.',
    );
  });
}
