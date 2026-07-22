import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('browse feed count label does not claim nearby', () {
    expect(DiscoverScreen.feedCountLabel(0), '0');
    expect(DiscoverScreen.feedCountLabel(12), '12');
    expect(
      DiscoverScreen.feedCountLabel(3).toLowerCase(),
      isNot(contains('nearby')),
    );
    expect(
      DiscoverScreen.feedCountLabel(3).toLowerCase(),
      isNot(contains('पास')),
    );
  });
}
