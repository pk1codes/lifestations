import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marriage form model validates age and photos; bio optional', () {
    expect(
      const MarriageProfile(
        age: 28,
        gender: 'woman',
        seeking: 'man',
        bio: '',
        cityId: 'mumbai',
        photoCount: 1,
      ).isValid,
      isTrue,
    );
  });

  test('jobs trades and salary bands are complete', () {
    expect(JobsProfile.trades, contains('Driver'));
    expect(JobsProfile.trades.length, greaterThanOrEqualTo(12));
    expect(JobsProfile.salaryBands.first, 'Prefer not to say');
  });

  test('rooms and bikes cardinality', () {
    expect(
      const RoomsOffer(
        type: '1 BHK',
        furnishing: 'Semi',
        monthlyRent: 15000,
        depositMonths: 2,
        cityId: 'delhi',
        photoCount: 2,
      ).isValid,
      isTrue,
    );
    expect(
      const BikesOffer(
        type: 'Scooter',
        transmission: 'automatic',
        make: 'Honda',
        hourlyRent: 80,
        photoCount: 4,
        hasRc: true,
      ).publicAttributes.containsKey('rcUrl'),
      isFalse,
    );
  });

  test('home help worker requires photo; need may omit', () {
    expect(
      const HomeHelpOffer(
        role: 'need',
        service: 'Cook',
        shift: 'Part-time',
        salaryBand: '₹8–12k',
        languages: ['Hindi'],
        photoCount: 0,
      ).isValid,
      isTrue,
    );
  });
}
