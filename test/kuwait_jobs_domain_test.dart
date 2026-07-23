import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/card_side.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flut_marriage/services/phone_number.dart';
import 'package:flut_marriage/state/app_stores.dart';
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
      tradeIds: ['Tool Pusher'],
      countryId: 'kuwait',
      salaryBand: 'Under KWD 100/mo',
      nationality: 'Indian',
      experienceBand: '1–3',
      photoCount: 1,
    );
    expect(available.isValid, isTrue);
    expect(available.tradeId, 'Tool Pusher');
    expect(KuwaitJobsProfile.roleLabel('seek'), 'Available');
    expect(KuwaitJobsProfile.roleLabel('offer'), 'Wanted');

    const wanted = KuwaitJobsProfile(
      role: 'offer',
      tradeIds: ['Cook', 'Helper', 'Driver-Pickup'],
      countryId: 'saudi',
      salaryBand: 'SAR 200–400/mo',
      nationality: 'Pakistan',
      experienceBand: '5+',
      photoCount: 0,
      howMany: 'Team',
    );
    expect(wanted.isValid, isTrue);
    expect(wanted.tradeIds.length, 3);
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
    expect(KuwaitJobsProfile.trades, contains('Cementing Engineer'));
    expect(KuwaitJobsProfile.trades, contains('Field Helper'));
    for (final trade in KuwaitJobsProfile.requiredTrades) {
      expect(KuwaitJobsProfile.trades, contains(trade), reason: trade);
    }
    expect(KuwaitJobsProfile.trades, isNot(contains('AD')));
    expect(
      KuwaitJobsProfile.trades,
      orderedEquals(
        [...KuwaitJobsProfile.trades]..sort(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
        ),
      ),
    );
    expect(KuwaitJobsProfile.trades.length, greaterThanOrEqualTo(55));
  });

  test('Kuwait Jobs allows 1–5 trades and title shows first +N', () {
    expect(KuwaitJobsProfile.titleLine(['Cook']), 'Cook');
    expect(KuwaitJobsProfile.titleLine(['Cook', 'Helper', 'Driver-Pickup']), 'Cook +2');
    expect(
      KuwaitJobsProfile.normalizeTrades([
        'Cook',
        'Helper',
        'Driver-Pickup',
        'Driller',
        'Floorman',
        'Medic',
      ]).length,
      KuwaitJobsProfile.maxTrades,
    );

    final tooMany = KuwaitJobsProfile(
      role: 'seek',
      tradeIds: List<String>.generate(
        6,
        (i) => KuwaitJobsProfile.trades[i],
      ),
      countryId: 'kuwait',
      salaryBand: 'Under KWD 100/mo',
      nationality: 'Indian',
      experienceBand: '1–3',
      photoCount: 1,
    );
    expect(tooMany.isValid, isFalse);

    final card = ListingPublisher().buildKuwaitJobsCard(
      ownerId: 'u1',
      offerId: 'k1',
      profile: const KuwaitJobsProfile(
        role: 'seek',
        tradeIds: ['Cementing Engineer', 'Field Helper', 'Cementer'],
        countryId: 'kuwait',
        salaryBand: 'KWD 200–400/mo',
        nationality: 'Indian',
        experienceBand: '1–3',
        photoCount: 1,
      ),
      photoUrls: const ['https://example.com/a.jpg'],
    );
    expect(card.title, 'Cementing Engineer +2');
    expect(card.categoryTags, [
      'Cementing Engineer',
      'Field Helper',
      'Cementer',
    ]);
    expect(cardTitleLine(card), 'Cementing Engineer +2');
  });

  test('Browse filter matches if any selected job overlaps', () {
    final store = DiscoveryStore(AppDomainId.kuwaitJobs);
    store.load([
      DiscoveryCardModel(
        id: 'a',
        domain: AppDomainId.kuwaitJobs,
        ownerId: 'u1',
        title: 'Cook +1',
        subtitle: 'KWD 200–400/mo',
        cityId: 'kuwait',
        cityLabel: 'Kuwait',
        categoryTags: const ['Cook', 'Helper'],
        imageUrls: const [],
        role: 'seek',
        attributes: const {
          'tradeId': 'Cook',
          'tradeIds': ['Cook', 'Helper'],
        },
      ),
    ]);
    expect(store.filtered(tradeId: 'Helper').map((c) => c.id), ['a']);
    expect(store.filtered(tradeId: 'Cook').map((c) => c.id), ['a']);
    expect(store.filtered(tradeId: 'Driller'), isEmpty);
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
