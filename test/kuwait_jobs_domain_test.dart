import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kuwait Jobs is first in dial order', () {
    expect(AppDomains.all.first.id, AppDomainId.kuwaitJobs);
    expect(AppDomains.kuwaitJobs.slug, 'kuwait_jobs');
    expect(AppDomains.kuwaitJobs.label, 'Kuwait Jobs');
  });

  test('Kuwait Jobs profile validates Available and Wanted', () {
    const available = KuwaitJobsProfile(
      role: 'seek',
      tradeId: 'Tool Pusher',
      countryId: 'kuwait',
      salaryBand: 'Under KWD 100/mo',
      nationality: 'Indian',
      experienceBand: '1–3',
      photoCount: 1,
    );
    expect(available.isValid, isTrue);
    expect(KuwaitJobsProfile.roleLabel('seek'), 'Available');
    expect(KuwaitJobsProfile.roleLabel('offer'), 'Wanted');

    const wanted = KuwaitJobsProfile(
      role: 'offer',
      tradeId: 'Cook',
      countryId: 'saudi',
      salaryBand: 'SAR 200–400/mo',
      nationality: 'Pakistan',
      experienceBand: '5+',
      photoCount: 0,
      howMany: 'Team',
    );
    expect(wanted.isValid, isTrue);
    expect(KuwaitJobsProfile.currencyFor('others'), 'USD');
    expect(KuwaitJobsProfile.trades, contains('Derrikman'));
    expect(KuwaitJobsProfile.trades, contains('Rig Superintendent'));
    expect(KuwaitJobsProfile.trades, contains('Receptionist'));
    expect(KuwaitJobsProfile.trades, contains('Home Maid'));
    expect(KuwaitJobsProfile.trades, contains('AC Mechanic'));
    expect(KuwaitJobsProfile.trades, contains('DD Planner'));
    expect(KuwaitJobsProfile.trades, contains('DD/Mwd Coordinator'));
    expect(KuwaitJobsProfile.trades, contains('MWD'));
    expect(KuwaitJobsProfile.trades, contains('Office Jobs'));
    expect(KuwaitJobsProfile.trades, contains('Storekeeper'));
    expect(KuwaitJobsProfile.trades, isNot(contains('AD')));
    expect(
      KuwaitJobsProfile.trades,
      orderedEquals(
        [...KuwaitJobsProfile.trades]..sort(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
        ),
      ),
    );
  });

  test('salary bands follow country currency', () {
    expect(
      KuwaitJobsProfile.salaryBandsFor('uae').any((s) => s.contains('AED')),
      isTrue,
    );
    expect(
      KuwaitJobsProfile.salaryBandsFor('others').any((s) => s.contains('USD')),
      isTrue,
    );
  });

  test('dial match prefers longer codes (Bangladesh over China)', () {
    final parts = splitStoredPhone('8801712345678');
    expect(parts.dial, PhoneDialCode.bangladesh);
    expect(parts.national, '1712345678');
    expect(PhoneDialCode.all.length, greaterThanOrEqualTo(11));
  });
}
