import 'package:flut_marriage/models/cities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('city list is short labels sorted A–Z', () {
    expect(cityLabels.length, greaterThanOrEqualTo(28));
    expect(cityLabels['mumbai'], 'Mumbai');
    expect(cityLabels['delhi'], 'Delhi NCR');
    expect(cityLabels['jaipur'], 'Jaipur');
    final labels = citiesAz.map((e) => e.value).toList();
    final sorted = [...labels]..sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    expect(labels, sorted);
  });
}
