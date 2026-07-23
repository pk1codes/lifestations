/// External store / install links used by public share cards.
abstract final class StoreLinks {
  static const playStore = String.fromEnvironment(
    'PLAY_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=com.lifestations.app',
  );

  /// Play install referrer so a later app open can recover the shared slug.
  static String playStoreForShareSlug(String slug) {
    final clean = slug.trim();
    if (clean.isEmpty) return playStore;
    final referrer = Uri.encodeComponent(
      'utm_source=share&utm_medium=card&utm_content=$clean',
    );
    return '$playStore&referrer=$referrer';
  }
}
