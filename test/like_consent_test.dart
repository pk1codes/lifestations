import 'package:flut_marriage/models/like_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LikeConsent copy is consistent consent-to-chat (all domains)', () {
    expect(LikeConsent.acceptCta, 'Accept — chat');
    expect(LikeConsent.acceptingCta, 'Accepting…');
    expect(LikeConsent.mutualDetail, 'Both interested — WhatsApp');
    expect(LikeConsent.inboundHint, contains('Accept to chat'));
    expect(LikeConsent.outboundWaiting, 'Waiting for them');
    expect(LikeConsent.acceptFirst, contains('Accept first'));
  });
}
