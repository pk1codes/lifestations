import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/widgets/domain_sphere_selector.dart';

void main() {
  Widget host({required ValueChanged<AppDomainId> onSelect}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: DomainSphereSelector(
            selected: AppDomainId.marriage,
            onDomainSelected: onSelect,
          ),
        ),
      ),
    );
  }

  testWidgets('renders all five domain stations on the sphere', (
    tester,
  ) async {
    await tester.pumpWidget(host(onSelect: (_) {}));
    await tester.pump();
    for (final domain in AppDomains.all) {
      expect(
        find.byKey(Key('sphere_domain_${domain.id.name}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('tapping a front-facing station selects its domain', (
    tester,
  ) async {
    AppDomainId? selected;
    await tester.pumpWidget(host(onSelect: (id) => selected = id));
    // Let the entrance animation finish so stations are hittable.
    await tester.pump(const Duration(milliseconds: 750));

    // With the initial orientation the rooms station sits on the front
    // hemisphere and is tappable; back-hemisphere stations ignore taps.
    await tester.tap(
      find.byKey(const Key('sphere_domain_rooms')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(selected, AppDomainId.rooms);

    await tester.tap(
      find.byKey(const Key('sphere_domain_marriage')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(selected, AppDomainId.rooms, reason: 'back icon must not select');
  });

  testWidgets('dragging rotates the sphere without errors', (tester) async {
    await tester.pumpWidget(host(onSelect: (_) {}));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.drag(find.byType(DomainSphereSelector), const Offset(80, 40));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  test('domain short lines stay plain and short', () {
    for (final domain in AppDomains.all) {
      final line = domainShortLine(domain.id);
      expect(line.isNotEmpty, isTrue);
      expect(line.split(' ').length, lessThanOrEqualTo(5));
    }
  });
}
