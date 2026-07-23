import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';

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
      final countryId = detail.attributes['countryId'] as String?;
      final cityId = countryId ?? city.$1;
      final cityLabel = countryId != null
          ? (KuwaitJobsProfile.countryLabels[countryId] ?? countryId)
          : city.$2;
      return DiscoveryCardModel(
        id: 'demo_${policy.slug}_${index + 1}',
        domain: domain,
        ownerId: 'demo_owner_${policy.slug}_${index + 1}',
        title: detail.title,
        subtitle: detail.subtitle,
        cityId: cityId,
        cityLabel: cityLabel,
        categoryTags: detail.tags,
        // Seed WebPs are not Flutter assets (keeps release AAB lean).
        // Debug demos use placeholder artwork in the UI.
        imageUrls: const <String>[],
        role: detail.role,
        ageBand: detail.ageBand,
        attributes: detail.attributes,
        verified: index.isEven,
        refreshed: index % 3 == 0,
        promoted: index == 0,
      );
    });
  }

  _SeedDetail _detail(AppDomainId domain, int index) {
    switch (domain) {
      case AppDomainId.marriage:
        final age = <String>['25-29', '30-34', '35-39'][index % 3];
        final gender = <String>['woman', 'man', 'other'][index % 3];
        final seeking = <String>['man', 'woman', 'everyone'][index % 3];
        return _SeedDetail(
          title: age,
          subtitle: '',
          tags: [gender],
          role: seeking,
          ageBand: age,
          attributes: {'synthetic': true, 'gender': gender, 'seeking': seeking},
        );
      case AppDomainId.jobs:
        final trades = <String>['Driver', 'Cook', 'Electrician'];
        final trade = trades[index % 3];
        final role = index.isEven ? 'seek' : 'offer';
        final pay = <String>['₹15–25k', '₹10–15k', '₹20–30k'][index % 3];
        return _SeedDetail(
          title: trade,
          subtitle: pay,
          tags: [trade.toLowerCase()],
          role: role,
          attributes: {'synthetic': true, 'tradeId': trade, 'salaryBand': pay},
        );
      case AppDomainId.kuwaitJobs:
        final trades = <String>['Driller', 'Cook', 'Driver-Pickup'];
        final trade = trades[index % 3];
        final role = index.isEven ? 'seek' : 'offer';
        final countries = <String>['kuwait', 'saudi', 'uae'];
        final country = countries[index % 3];
        final nationality = <String>['Indian', 'Pakistan', 'Egyptian'][index % 3];
        final experience = <String>['0–1', '1–3', '5+'][index % 3];
        final pay = <String>[
          'KWD 200–400/mo',
          'SAR 200–400/mo',
          'AED 200–400/mo',
        ][index % 3];
        return _SeedDetail(
          title: trade,
          subtitle: pay,
          tags: [trade.toLowerCase()],
          role: role,
          attributes: {
            'synthetic': true,
            'tradeId': trade,
            'salaryBand': pay,
            'countryId': country,
            'nationality': nationality,
            'experienceBand': experience,
          },
        );
      case AppDomainId.rooms:
        final types = <String>['Room', 'Studio', '1 BHK'];
        final type = types[index % 3];
        final role = index.isEven ? 'have' : 'need';
        final rent = <int>[8000, 12000, 15000][index % 3];
        return _SeedDetail(
          title: type,
          subtitle: '₹$rent/month',
          tags: [type.toLowerCase()],
          role: role,
          attributes: {'synthetic': true, 'type': type, 'monthlyRent': rent},
        );
      case AppDomainId.bikes:
        final makes = <String>['Honda', 'TVS', 'Bajaj'];
        final types = <String>['Scooter', 'Bike', 'Bike'];
        final make = makes[index % 3];
        final type = types[index % 3];
        final role = index.isEven ? 'lend' : 'need';
        final rate = <int>[50, 80, 100][index % 3];
        return _SeedDetail(
          title: '$make $type',
          subtitle: '₹$rate/hour',
          tags: [type.toLowerCase(), make],
          role: role,
          attributes: {
            'synthetic': true,
            'make': make,
            'type': type,
            'hourlyRent': rate,
          },
        );
      case AppDomainId.homeHelp:
        final services = <String>['Cook', 'Maid', 'Elder care'];
        final service = services[index % 3];
        final role = index.isEven ? 'have' : 'need';
        final pay = <String>['₹8–12k', '₹10–15k', '₹12–18k'][index % 3];
        return _SeedDetail(
          title: service,
          subtitle: 'Part-time · $pay',
          tags: [service.toLowerCase()],
          role: role,
          attributes: {
            'synthetic': true,
            'service': service,
            'shift': 'Part-time',
            'salaryBand': pay,
          },
        );
    }
  }
}

class _SeedDetail {
  const _SeedDetail({
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.attributes,
    this.role,
    this.ageBand,
  });

  final String title;
  final String subtitle;
  final List<String> tags;
  final String? role;
  final String? ageBand;
  final Map<String, Object?> attributes;
}
