import 'package:flut_marriage/models/app_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each domain has a unique distinguishing color', () {
    final colors = AppDomains.all.map((d) => d.color.toARGB32()).toSet();
    expect(colors.length, AppDomains.all.length);
  });

  test('domain soft surfaces keep the domain hue', () {
    for (final domain in AppDomains.all) {
      expect(domain.softColor.a, closeTo(0.14, 0.001));
      expect(domain.softColor.r, domain.color.r);
      expect(domain.softColor.g, domain.color.g);
      expect(domain.softColor.b, domain.color.b);
    }
  });
}
