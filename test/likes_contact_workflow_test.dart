import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/contact_service.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('likes store mutual gate for connect', () {
    final likes = LikesStore()
      ..like(AppDomainId.rooms, 'owner')
      ..receiveLike(AppDomainId.rooms, 'owner');
    expect(
      likes.canUnlock(
        domain: AppDomainId.rooms,
        otherId: 'owner',
        anonymous: false,
        phoneVerified: true,
      ),
      isTrue,
    );
  });

  test('OTP throttle blocks rapid resend', () {
    final throttle = OtpThrottle();
    final now = DateTime(2026, 7, 19, 5);
    expect(throttle.record(now), isTrue);
    expect(throttle.record(now.add(const Duration(seconds: 10))), isFalse);
  });
}
