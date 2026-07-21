import 'package:flut_marriage/services/media_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const medium =
      'https://aaaa-4eee0.web.app/i/profile_photos/uid/marriage/0/medium.webp';

  test('derives thumb and large from medium CDN path', () {
    expect(
      MediaUrls.thumb(medium),
      'https://aaaa-4eee0.web.app/i/profile_photos/uid/marriage/0/thumb.webp',
    );
    expect(
      MediaUrls.large(medium),
      'https://aaaa-4eee0.web.app/i/profile_photos/uid/marriage/0/large.webp',
    );
    expect(MediaUrls.medium(medium), medium);
  });

  test('card role uses thumb preview then medium primary', () {
    expect(MediaUrls.preview(medium, FastImageRole.card), MediaUrls.thumb(medium));
    expect(MediaUrls.primary(medium, FastImageRole.card), medium);
    expect(MediaUrls.preview(medium, FastImageRole.thumb), isNull);
    expect(
      MediaUrls.primary(medium, FastImageRole.detail),
      MediaUrls.large(medium),
    );
  });

  test('non-http and unknown paths pass through', () {
    expect(MediaUrls.thumb('assets/a.webp'), 'assets/a.webp');
    const plain = 'https://cdn.example/photo.webp';
    expect(MediaUrls.thumb(plain), plain);
  });
}
