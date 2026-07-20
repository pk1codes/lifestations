import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/owned_post.dart';
import 'package:flut_marriage/services/owned_hydrate.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('marriageFromCard restores public metadata', () {
    final profile = marriageFromCard(
      const DiscoveryCardModel(
        id: 'u1',
        domain: AppDomainId.marriage,
        ownerId: 'u1',
        title: 'Marriage · 25-29',
        subtitle: 'Seeking man',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        categoryTags: ['woman'],
        imageUrls: ['https://cdn.example/a.webp'],
        role: 'man',
        ageBand: '25-29',
        attributes: {
          'gender': 'woman',
          'seeking': 'man',
          'education': 'Graduate',
        },
      ),
    );
    expect(profile, isNotNull);
    expect(profile!.gender, 'woman');
    expect(profile.seeking, 'man');
    expect(profile.age, 27);
    expect(profile.education, 'Graduate');
    expect(profile.photoCount, 1);
  });

  test('OwnedListingCache round-trips photo urls', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = OwnedListingCache(prefs);
    await cache.setPhotos(AppDomainId.marriage, const [
      'https://cdn.example/m.webp',
    ]);
    expect(cache.photos(AppDomainId.marriage), [
      'https://cdn.example/m.webp',
    ]);
  });

  test('resolveOwnedPhotoUrls prefers cache then card', () async {
    SharedPreferences.setMockInitialValues({
      'owned_photos_marriage': ['https://cdn.example/cached.webp'],
    });
    final prefs = await SharedPreferences.getInstance();
    final cache = OwnedListingCache(prefs);
    final urls = await resolveOwnedPhotoUrls(
      post: OwnedPost(
        domain: AppDomainId.marriage,
        card: const DiscoveryCardModel(
          id: 'u1',
          domain: AppDomainId.marriage,
          ownerId: 'u1',
          title: 'Marriage',
          subtitle: '',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          categoryTags: [],
          imageUrls: ['https://cdn.example/card.webp'],
        ),
      ),
      media: cache,
      ownerId: 'u1',
    );
    expect(urls, ['https://cdn.example/cached.webp']);
  });
}
