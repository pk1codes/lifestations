import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/contact_service.dart';
import 'package:flut_marriage/services/moderation/moderation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marriage derives equality-query age bands and validates bio', () {
    expect(
      const MarriageProfile(
        age: 29,
        gender: 'woman',
        seeking: 'man',
        bio: 'A calm synthetic profile.',
        cityId: 'mumbai',
        photoCount: 1,
      ).ageBand,
      '25-29',
    );
    expect(
      const MarriageProfile(
        age: 17,
        gender: 'woman',
        seeking: 'man',
        bio: 'A calm synthetic profile.',
        cityId: 'mumbai',
        photoCount: 1,
      ).isValid,
      isFalse,
    );
  });

  test('jobs generates need lines without free typing', () {
    const seeker = JobsProfile(
      role: 'seek',
      tradeId: 'Driver',
      cityId: 'delhi',
      salaryBand: '₹15–25k/mo',
      photoCount: 1,
    );
    expect(seeker.isValid, isTrue);
    expect(seeker.needLine, 'Driver');
  });

  test('bike requires exactly four photos and exposes booleans only', () {
    const bike = BikesOffer(
      type: 'Scooter',
      transmission: 'automatic',
      make: 'Honda',
      hourlyRent: 80,
      photoCount: 4,
      hasRc: true,
    );
    expect(bike.isValid, isTrue);
    expect(bike.publicAttributes['hasRc'], isTrue);
    expect(bike.publicAttributes.keys, isNot(contains('rcUrl')));
    expect(bike.publicAttributes.keys, isNot(contains('insuranceUrl')));
  });

  test('home request can omit photo while worker cannot', () {
    const request = HomeHelpOffer(
      role: 'need',
      service: 'Cook',
      shift: 'Part-time',
      salaryBand: '₹8–12k',
      languages: ['Hindi'],
      photoCount: 0,
      howMany: '2',
    );
    const worker = HomeHelpOffer(
      role: 'have',
      service: 'Cook',
      shift: 'Part-time',
      salaryBand: '₹8–12k',
      languages: ['Hindi'],
      photoCount: 0,
    );
    expect(request.isValid, isTrue);
    expect(worker.isValid, isFalse);
  });

  test('OTP send throttle enforces cooldown', () {
    final throttle = OtpThrottle();
    final now = DateTime(2026);
    expect(throttle.record(now), isTrue);
    expect(throttle.record(now.add(const Duration(seconds: 30))), isFalse);
    expect(throttle.record(now.add(const Duration(seconds: 61))), isTrue);
  });

  test('text scanner blocks disallowed standalone terms', () {
    const scanner = TextSafetyScanner();
    expect(scanner.scan('A friendly profile').safe, isTrue);
    expect(scanner.scan('Nude image request').safe, isFalse);
  });

  test('billable Vision is disabled without compile-time key', () {
    expect(GoogleVisionSafeSearchClient().enabled, isFalse);
  });
}
