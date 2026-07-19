import '../models/app_domain.dart';
import '../models/discovery_card.dart';

class SeedRepository {
  const SeedRepository();

  static const cities = <(String, String)>[
    ('mumbai', 'Mumbai & MMR'),
    ('delhi', 'Delhi NCR'),
    ('bengaluru', 'Bengaluru'),
  ];

  List<DiscoveryCardModel> forDomain(AppDomainId domain) {
    final policy = AppDomains.byId(domain);
    return List<DiscoveryCardModel>.generate(9, (index) {
      final city = cities[index ~/ 3];
      final detail = _detail(domain, index);
      return DiscoveryCardModel(
        id: 'demo_${policy.slug}_${index + 1}',
        domain: domain,
        ownerId: 'demo_owner_${policy.slug}_${index + 1}',
        title: detail.$1,
        subtitle: detail.$2,
        cityId: city.$1,
        cityLabel: city.$2,
        categoryTags: <String>[detail.$3],
        imageUrls: List<String>.generate(
          3,
          (photo) =>
              'initial_seeds/${policy.slug == 'marriage' ? '' : '${policy.slug}/'}photos/${policy.slug}_${index + 1}_${photo + 1}.webp',
        ),
        role: detail.$4,
        ageBand: domain == AppDomainId.marriage
            ? <String>['25-29', '30-34', '35-39'][index % 3]
            : null,
        attributes: <String, Object?>{
          'synthetic': true,
          if (domain == AppDomainId.marriage) ...{
            'gender': <String>['woman', 'man', 'other'][index % 3],
            'seeking': <String>['man', 'woman', 'everyone'][index % 3],
          },
        },
        verified: index.isEven,
        refreshed: index % 3 == 0,
        promoted: index == 0,
      );
    });
  }

  (String, String, String, String?) _detail(AppDomainId domain, int index) {
    switch (domain) {
      case AppDomainId.marriage:
        final titles = <String>[
          'Thoughtful & family-minded',
          'Curious, calm & kind',
          'Building a meaningful life',
        ];
        return (
          titles[index % 3],
          'Synthetic profile • ${cities[index ~/ 3].$2}',
          'intentional',
          null,
        );
      case AppDomainId.jobs:
        final trades = <String>['Driver', 'Cook', 'Electrician'];
        final trade = trades[index % 3];
        final role = index.isEven ? 'seek' : 'offer';
        return (
          role == 'seek' ? '$trade available' : '$trade needed',
          role == 'seek' ? 'Looking for $trade work' : 'Need $trade help',
          trade.toLowerCase(),
          role,
        );
      case AppDomainId.rooms:
        final types = <String>['Room', 'Studio', '1 BHK'];
        final role = index.isEven ? 'have' : 'need';
        final rent = <int>[8000, 12000, 15000][index % 3];
        return (
          role == 'have'
              ? '${types[index % 3]} for rent'
              : 'Looking for ${types[index % 3]}',
          role == 'have'
              ? '₹$rent/month'
              : 'Budget about ₹$rent/month',
          types[index % 3].toLowerCase(),
          role,
        );
      case AppDomainId.bikes:
        final types = <String>['Honda scooter', 'TVS bike', 'Bajaj bike'];
        final role = index.isEven ? 'lend' : 'need';
        final rate = <int>[50, 80, 100][index % 3];
        return (
          role == 'lend' ? types[index % 3] : 'Need ${types[index % 3]}',
          role == 'lend'
              ? '₹$rate/hour • 9 AM–8 PM'
              : 'Budget ₹$rate/hour',
          index.isEven ? 'scooter' : 'bike',
          role,
        );
      case AppDomainId.homeHelp:
        final roles = <String>['Cook', 'Maid', 'Elder care'];
        final role = index.isEven ? 'have' : 'need';
        return (
          role == 'have'
              ? '${roles[index % 3]} available'
              : '${roles[index % 3]} needed',
          '${role == 'have' ? 'Available' : 'Hiring'} • Part-time',
          roles[index % 3].toLowerCase(),
          role,
        );
    }
  }
}
