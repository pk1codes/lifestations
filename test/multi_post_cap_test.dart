import 'package:flut_marriage/models/app_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multi-offer domains allow several posts; marriage and jobs stay at one', () {
    expect(AppDomains.marriage.maxProfiles, 1);
    expect(AppDomains.jobs.maxProfiles, 1);
    expect(AppDomains.rooms.maxProfiles, 5);
    expect(AppDomains.bikes.maxProfiles, 5);
    expect(AppDomains.homeHelp.maxProfiles, 3);
  });

  test('can add while under cap', () {
    bool canAdd(int count, int max) => count < max;
    expect(canAdd(0, 5), isTrue);
    expect(canAdd(2, 5), isTrue);
    expect(canAdd(5, 5), isFalse);
    expect(canAdd(1, 1), isFalse);
    expect(canAdd(0, 1), isTrue);
  });
}
