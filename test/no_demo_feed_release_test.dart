import 'package:flut_marriage/config/feature_flags.dart';
import 'package:flut_marriage/services/domain_repository.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('withoutDemos strips bundled synthetic cards', () {
    const live = DiscoveryCardModel(
      id: 'real_1',
      domain: AppDomainId.kuwaitJobs,
      ownerId: 'uid_a',
      title: 'Cook',
      subtitle: '',
      cityId: 'kuwait',
      cityLabel: 'Kuwait',
      categoryTags: <String>['Cook'],
      imageUrls: <String>[],
    );
    const demo = DiscoveryCardModel(
      id: 'demo_kuwait_jobs_1',
      domain: AppDomainId.kuwaitJobs,
      ownerId: 'demo_owner_kuwait_jobs_1',
      title: 'Fake',
      subtitle: '',
      cityId: 'kuwait',
      cityLabel: 'Kuwait',
      categoryTags: <String>['Cook'],
      imageUrls: <String>[],
    );
    final kept = ScopedSyncEngine.withoutDemos([live, demo]);
    expect(kept, [live]);
  });

  test('ALLOW_DEMO_SEEDS override is compile-time only', () {
    // Default build: override is false; debug still allows seeds via !kReleaseMode.
    expect(FeatureFlags.allowDemoSeedsOverride, isFalse);
  });
}
