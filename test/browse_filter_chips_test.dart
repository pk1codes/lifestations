import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('browseActiveFilterLabels lists active marriage filters', () {
    final match = MatchPreferencesStore()
      ..update(city: 'mumbai', genderValue: 'woman', age: '25-29');
    final jobs = JobsDiscoverPrefsStore();

    expect(
      browseActiveFilterLabels(
        domainId: AppDomainId.marriage,
        match: match,
        jobs: jobs,
      ),
      ['Mumbai', 'woman', '25-29'],
    );

    match.clear();
    expect(
      browseActiveFilterLabels(
        domainId: AppDomainId.marriage,
        match: match,
        jobs: jobs,
      ),
      isEmpty,
    );
    expect(match.hasActive, isFalse);
  });

  test('browseActiveFilterLabels lists active jobs filters', () {
    final match = MatchPreferencesStore();
    final jobs = JobsDiscoverPrefsStore()
      ..update(city: 'delhi', roleValue: 'seek', trade: 'Driver');

    expect(
      browseActiveFilterLabels(
        domainId: AppDomainId.jobs,
        match: match,
        jobs: jobs,
      ),
      ['Delhi NCR', 'I have', 'Driver'],
    );

    jobs.clear();
    expect(jobs.hasActive, isFalse);
  });

  test('rooms only surfaces city filter chips', () {
    final match = MatchPreferencesStore()
      ..update(city: 'bengaluru', genderValue: 'man', age: '30-34');
    final jobs = JobsDiscoverPrefsStore();

    expect(
      browseActiveFilterLabels(
        domainId: AppDomainId.rooms,
        match: match,
        jobs: jobs,
      ),
      ['Bengaluru'],
    );
  });
}
