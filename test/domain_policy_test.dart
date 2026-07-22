import 'package:flut_marriage/models/app_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical domain policies preserve release boundaries', () {
    expect(AppDomains.all, hasLength(5));
    expect(
      AppDomains.all
          .where((domain) => domain.enabled)
          .map((domain) => domain.id),
      AppDomainId.values,
    );
    expect(AppDomains.marriage.storageKind, DomainStorageKind.profiles);
    expect(AppDomains.marriage.mediaPolicy, MediaPolicy.face);
    expect(AppDomains.marriage.maxProfiles, 1);
    expect(AppDomains.marriage.maxPhotos, 3);
    expect(AppDomains.jobs.roles, ['seek', 'offer']);
    expect(AppDomains.jobs.storageKind, DomainStorageKind.offers);
    expect(AppDomains.jobs.maxProfiles, 5);
    expect(AppDomains.rooms.maxProfiles, 5);
    expect(AppDomains.rooms.minPhotos, 2);
    expect(AppDomains.rooms.maxPhotos, 8);
    expect(AppDomains.bikes.minPhotos, 4);
    expect(AppDomains.bikes.maxPhotos, 4);
    expect(AppDomains.homeHelp.mediaPolicy, MediaPolicy.either);
    expect(AppDomains.homeHelp.roles, ['need', 'have']);
    expect(AppDomains.homeHelp.maxProfiles, 5);
  });

  test('repository paths match storage policy', () {
    expect(AppDomains.marriage.collection, 'domains/marriage/profiles');
    expect(AppDomains.jobs.collection, 'domains/jobs/offers');
    expect(AppDomains.rooms.collection, 'domains/rooms/offers');
    expect(AppDomains.homeHelp.collection, 'domains/home_help/offers');
  });
}
