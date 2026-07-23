import 'package:flut_marriage/models/app_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical domain policies preserve release boundaries', () {
    expect(AppDomains.all, hasLength(6));
    expect(AppDomains.all.map((domain) => domain.id), [
      AppDomainId.kuwaitJobs,
      AppDomainId.marriage,
      AppDomainId.jobs,
      AppDomainId.rooms,
      AppDomainId.bikes,
      AppDomainId.homeHelp,
    ]);
    expect(AppDomains.all.every((domain) => domain.enabled), isTrue);
    expect(AppDomains.kuwaitJobs.slug, 'kuwait_jobs');
    expect(AppDomains.kuwaitJobs.roles, ['seek', 'offer']);
    expect(AppDomains.kuwaitJobs.storageKind, DomainStorageKind.offers);
    expect(AppDomains.kuwaitJobs.maxProfiles, 5);
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
    expect(AppDomains.kuwaitJobs.collection, 'domains/kuwait_jobs/offers');
    expect(AppDomains.rooms.collection, 'domains/rooms/offers');
    expect(AppDomains.homeHelp.collection, 'domains/home_help/offers');
  });
}
