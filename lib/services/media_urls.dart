/// Helpers for CDN photo URLs that store thumb / medium / large variants.
///
/// Uploads write all three under the same prefix; listings usually keep only
/// the medium URL. We derive the others by path so older docs still work.
library;

enum MediaVariant { thumb, medium, large }

/// Which on-screen role the image fills — drives decode size + which variants load.
enum FastImageRole {
  /// Likes list / Me avatar / form slot (~72–96 px).
  thumb,

  /// Browse card hero / pager page.
  card,

  /// Full-width detail sheet.
  detail,
}

class MediaUrls {
  MediaUrls._();

  static final _variantSegment = RegExp(r'/(thumb|medium|large)\.');

  /// Returns a sibling variant URL, or [url] when the path has no size segment.
  static String variant(String url, MediaVariant target) {
    if (!_isHttp(url)) return url;
    if (!_variantSegment.hasMatch(url)) return url;
    return url.replaceFirst(_variantSegment, '/${target.name}.');
  }

  static String thumb(String url) => variant(url, MediaVariant.thumb);
  static String medium(String url) => variant(url, MediaVariant.medium);
  static String large(String url) => variant(url, MediaVariant.large);

  /// Best URL to fetch for [role] (after an optional thumb blur-up).
  static String primary(String url, FastImageRole role) {
    switch (role) {
      case FastImageRole.thumb:
        return thumb(url);
      case FastImageRole.card:
        return medium(url);
      case FastImageRole.detail:
        // Prefer large when the path supports it; falls back to medium.
        return large(url);
    }
  }

  /// Low-res stand-in shown first for card/detail (skipped for tiny thumbs).
  static String? preview(String url, FastImageRole role) {
    if (!_isHttp(url)) return null;
    if (role == FastImageRole.thumb) return null;
    final t = thumb(url);
    final p = primary(url, role);
    return t == p ? null : t;
  }

  static bool _isHttp(String url) =>
      url.startsWith('http://') || url.startsWith('https://');
}
