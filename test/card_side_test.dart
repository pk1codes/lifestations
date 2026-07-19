import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/card_side.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jobs and home help map seek/have to I have and offer/need to I need', () {
    const haveJob = DiscoveryCardModel(
      id: '1',
      domain: AppDomainId.jobs,
      ownerId: 'a',
      title: 'Driver available',
      subtitle: 'Looking for work',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: ['driver'],
      imageUrls: [],
      role: 'seek',
    );
    const needJob = DiscoveryCardModel(
      id: '2',
      domain: AppDomainId.jobs,
      ownerId: 'b',
      title: 'Driver needed',
      subtitle: 'Hiring',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: ['driver'],
      imageUrls: [],
      role: 'offer',
    );
    expect(cardSideMark(haveJob)?.side, MarketplaceSide.supply);
    expect(cardSideMark(haveJob)?.label, 'I have');
    expect(cardSideMark(needJob)?.side, MarketplaceSide.demand);
    expect(cardSideMark(needJob)?.label, 'I need');

    const haveHelp = DiscoveryCardModel(
      id: '3',
      domain: AppDomainId.homeHelp,
      ownerId: 'c',
      title: 'Cook available',
      subtitle: 'Part-time',
      cityId: 'delhi',
      cityLabel: 'Delhi',
      categoryTags: ['cook'],
      imageUrls: [],
      role: 'have',
    );
    const needHelp = DiscoveryCardModel(
      id: '4',
      domain: AppDomainId.homeHelp,
      ownerId: 'd',
      title: 'Cook needed',
      subtitle: 'Hiring',
      cityId: 'delhi',
      cityLabel: 'Delhi',
      categoryTags: ['cook'],
      imageUrls: [],
      role: 'need',
    );
    expect(cardSideMark(haveHelp)?.side, MarketplaceSide.supply);
    expect(cardSideMark(needHelp)?.side, MarketplaceSide.demand);
  });

  test('rooms and bikes distinguish have vs need', () {
    const haveRoom = DiscoveryCardModel(
      id: '5',
      domain: AppDomainId.rooms,
      ownerId: 'e',
      title: 'Room for rent',
      subtitle: '₹8000/month',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: ['room'],
      imageUrls: [],
      role: 'have',
      attributes: {'type': 'Room', 'monthlyRent': 8000},
    );
    const needRoom = DiscoveryCardModel(
      id: '6',
      domain: AppDomainId.rooms,
      ownerId: 'f',
      title: 'Looking for room',
      subtitle: 'Budget',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: ['room'],
      imageUrls: [],
      role: 'need',
    );
    expect(cardSideMark(haveRoom)?.label, 'I have');
    expect(cardSideMark(needRoom)?.label, 'I need');
    expect(cardFactLine(haveRoom), 'Room • ₹8000/month');
  });

  test('marriage uses looking-for mark, not marketplace sides', () {
    const card = DiscoveryCardModel(
      id: '7',
      domain: AppDomainId.marriage,
      ownerId: 'g',
      title: 'Profile',
      subtitle: 'Synthetic',
      cityId: 'delhi',
      cityLabel: 'Delhi',
      categoryTags: [],
      imageUrls: [],
      ageBand: '25-29',
      attributes: {'gender': 'woman', 'seeking': 'man'},
    );
    expect(cardSideMark(card)?.side, MarketplaceSide.match);
    expect(cardSideMark(card)?.label, 'Looking for man');
    expect(cardFactLine(card), '25-29 • woman');
  });
}
