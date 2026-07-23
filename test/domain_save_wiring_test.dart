import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Confirms every domain can build a publishable card (Save → ListingPublisher).
void main() {
  final publisher = ListingPublisher();

  test('Marriage Save payload builds a valid discovery card', () {
    final card = publisher.buildMarriageCard(
      ownerId: 'u1',
      profile: const MarriageProfile(
        age: 28,
        gender: 'woman',
        seeking: 'man',
        bio: '',
        cityId: 'mumbai',
        photoCount: 1,
      ),
      photoUrls: const ['https://cdn.example/m.webp'],
    );
    expect(card.domain, AppDomainId.marriage);
    expect(card.ownerId, 'u1');
    expect(card.imageUrls, isNotEmpty);
    expect(DiscoveryCardModel.isPublicSafe(card.toPublicJson()), isTrue);
  });

  test('Jobs Save payload builds a valid discovery card', () {
    final card = publisher.buildJobsCard(
      ownerId: 'u1',
      offerId: 'jobs_1',
      profile: const JobsProfile(
        role: 'seek',
        tradeId: 'Driver',
        cityId: 'delhi',
        salaryBand: 'Prefer not to say',
        photoCount: 1,
      ),
      photoUrls: const ['https://cdn.example/j.webp'],
    );
    expect(card.domain, AppDomainId.jobs);
    expect(card.id, 'jobs_1');
    expect(card.title, contains('Driver'));
  });

  test('Jobs demand includes how many', () {
    final card = publisher.buildJobsCard(
      ownerId: 'u1',
      offerId: 'jobs_need',
      profile: const JobsProfile(
        role: 'offer',
        tradeId: 'Security',
        cityId: 'mumbai',
        salaryBand: '₹15–25k/mo',
        howMany: 'Team',
      ),
    );
    expect(card.attributes['howMany'], 'Team');
    expect(card.role, 'offer');
  });

  test('Rooms Save payload builds a valid discovery card', () {
    final card = publisher.buildRoomsCard(
      ownerId: 'u1',
      offerId: 'rooms_1',
      offer: const RoomsOffer(
        type: '1 BHK',
        furnishing: 'Semi',
        monthlyRent: 15000,
        depositMonths: 1,
        cityId: 'mumbai',
        photoCount: 2,
      ),
      photoUrls: const [
        'https://cdn.example/r0.webp',
        'https://cdn.example/r1.webp',
      ],
    );
    expect(card.domain, AppDomainId.rooms);
    expect(card.id, 'rooms_1');
    expect(card.role, 'have');
  });

  test('Bikes Save payload builds a valid discovery card', () {
    final card = publisher.buildBikesCard(
      ownerId: 'u1',
      offerId: 'bikes_1',
      offer: const BikesOffer(
        type: 'Scooter',
        transmission: 'automatic',
        make: 'Honda',
        hourlyRent: 80,
        photoCount: 4,
      ),
      photoUrls: const [
        'https://cdn.example/b0.webp',
        'https://cdn.example/b1.webp',
        'https://cdn.example/b2.webp',
        'https://cdn.example/b3.webp',
      ],
    );
    expect(card.domain, AppDomainId.bikes);
    expect(card.role, 'lend');
  });

  test('Home Help Save payload builds a valid discovery card', () {
    final card = publisher.buildHomeHelpCard(
      ownerId: 'u1',
      offerId: 'home_1',
      offer: const HomeHelpOffer(
        role: 'have',
        service: 'Cook',
        shift: 'Part-time',
        salaryBand: '₹8–12k',
        languages: ['Hindi'],
        photoCount: 1,
        cityId: 'mumbai',
      ),
      photoUrls: const ['https://cdn.example/h.webp'],
    );
    expect(card.domain, AppDomainId.homeHelp);
    expect(card.role, 'have');
  });

  test('all domains are enabled for New post / Save', () {
    expect(
      AppDomains.all.where((d) => d.enabled).map((d) => d.id),
      containsAll([
        AppDomainId.kuwaitJobs,
        AppDomainId.marriage,
        AppDomainId.jobs,
        AppDomainId.rooms,
        AppDomainId.bikes,
        AppDomainId.homeHelp,
      ]),
    );
  });
}
