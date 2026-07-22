import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/discovery_feed_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiscoveryCardModel _card({
  required String id,
  String title = 'Room',
  int? refreshedAtMs,
  List<String> photos = const ['https://example.com/a.jpg'],
}) {
  return DiscoveryCardModel(
    id: id,
    domain: AppDomainId.rooms,
    ownerId: 'owner_$id',
    title: title,
    subtitle: '',
    cityId: 'mumbai',
    cityLabel: 'Mumbai',
    categoryTags: const <String>[],
    imageUrls: photos,
    refreshedAtMs: refreshedAtMs,
  );
}

void main() {
  test('merge keeps local object when stamp unchanged', () {
    final local = _card(id: 'a', refreshedAtMs: 100);
    final remote = _card(id: 'a', refreshedAtMs: 100);
    final merged = DiscoveryFeedCache.mergeKeepingUnchanged([local], [remote]);
    expect(identical(merged.single, local), isTrue);
  });

  test('merge replaces when backend stamp changed', () {
    final local = _card(id: 'a', title: 'Old', refreshedAtMs: 100);
    final remote = _card(id: 'a', title: 'New', refreshedAtMs: 200);
    final merged = DiscoveryFeedCache.mergeKeepingUnchanged([local], [remote]);
    expect(merged.single.title, 'New');
    expect(merged.single.refreshedAtMs, 200);
  });

  test('merge replaces when photo list changes without stamp', () {
    final local = _card(id: 'a', photos: const ['https://ex.com/1.jpg']);
    final remote = _card(id: 'a', photos: const ['https://ex.com/2.jpg']);
    final merged = DiscoveryFeedCache.mergeKeepingUnchanged([local], [remote]);
    expect(merged.single.imageUrls.single, 'https://ex.com/2.jpg');
  });

  test('prefs round-trip skips demos', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = DiscoveryFeedCache(prefs);
    await cache.write(AppDomainId.rooms, [
      _card(id: 'live1', refreshedAtMs: 9),
      _card(
        id: 'demo_x',
        refreshedAtMs: 1,
      ).copyWith(id: 'demo_x', ownerId: 'demo_owner_x'),
    ]);
    final read = cache.read(AppDomainId.rooms);
    expect(read.map((c) => c.id), ['live1']);
    expect(read.single.refreshedAtMs, 9);
  });
}
