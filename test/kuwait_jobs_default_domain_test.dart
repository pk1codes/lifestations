import 'package:flut_marriage/config/store_links.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/share_install_referrer.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('newcomers default to Kuwait Jobs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = DomainController(prefs);
    expect(controller.selected, AppDomainId.kuwaitJobs);
  });

  test('last visited domain persists', () async {
    SharedPreferences.setMockInitialValues({
      'selected_domain': AppDomainId.rooms.index,
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = DomainController(prefs);
    expect(controller.selected, AppDomainId.rooms);
    controller.selectDomain(AppDomainId.jobs);
    expect(prefs.getInt('selected_domain'), AppDomainId.jobs.index);
  });

  test('Play Store share URL includes slug referrer', () {
    final url = StoreLinks.playStoreForShareSlug('kuwait_jobs_abc123');
    expect(url, contains('com.lifestations.app'));
    expect(url, contains('referrer='));
    expect(url, contains('kuwait_jobs_abc123'));
  });

  test('install referrer parses utm_content slug', () {
    expect(
      ShareInstallReferrer.parseSlugFromReferrer(
        'utm_source=share&utm_medium=card&utm_content=kuwait_jobs_abc123',
      ),
      'kuwait_jobs_abc123',
    );
    expect(
      ShareInstallReferrer.parseSlugFromReferrer(
        Uri.encodeComponent(
          'utm_source=share&utm_medium=card&utm_content=rooms_Zz9abc',
        ),
      ),
      'rooms_Zz9abc',
    );
    expect(ShareInstallReferrer.parseSlugFromReferrer(''), isNull);
    expect(
      ShareInstallReferrer.parseSlugFromReferrer('utm_source=google-play'),
      isNull,
    );
  });
}
