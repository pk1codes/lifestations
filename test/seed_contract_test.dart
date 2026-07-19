import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed manifest describes 45 cards and 135 unique WebPs', () {
    final manifest =
        jsonDecode(File('initial_seeds/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final counts = manifest['counts'] as Map<String, dynamic>;
    expect(manifest['synthetic'], isTrue);
    expect(counts['cards'], 45);
    expect(counts['images'], 135);
    expect(counts['uniqueSha256'], 135);
    expect(manifest['dimensions'], {'width': 1800, 'height': 2400});
    expect(manifest['domains'], hasLength(5));
    expect(manifest['images'], hasLength(135));
    expect(
      Directory('initial_seeds')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.webp')),
      hasLength(135),
    );
  });
}
