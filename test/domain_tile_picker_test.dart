import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/widgets/domain_tile_picker.dart';

void main() {
  Widget host({
    required ValueChanged<AppDomainId> onSelect,
    AppDomainId selected = AppDomainId.marriage,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DomainTilePicker(
            selected: selected,
            onDomainSelected: onSelect,
          ),
        ),
      ),
    );
  }

  testWidgets('renders Google-style icon grid with labels under icons', (
    tester,
  ) async {
    await tester.pumpWidget(host(onSelect: (_) {}));
    await tester.pump();
    expect(find.byKey(const Key('domain_apps_grid')), findsOneWidget);
    for (final domain in AppDomains.all) {
      expect(find.byKey(Key('domain_tile_${domain.id.name}')), findsOneWidget);
    }
    expect(find.text('Marriage'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Bikes'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // Both rows fully laid out — Help (row 2) is hittable, not clipped.
    final help = tester.getRect(find.byKey(const Key('domain_tile_homeHelp')));
    final marriage = tester.getRect(
      find.byKey(const Key('domain_tile_marriage')),
    );
    expect(help.height, DomainTilePicker.cellHeight);
    expect(marriage.height, DomainTilePicker.cellHeight);
    expect(help.top, greaterThan(marriage.bottom - 1));
  });

  testWidgets('tapping a cell selects its domain', (tester) async {
    AppDomainId? selected;
    await tester.pumpWidget(host(onSelect: (id) => selected = id));
    await tester.pump();

    await tester.tap(find.byKey(const Key('domain_tile_rooms')));
    await tester.pump();
    expect(selected, AppDomainId.rooms);

    await tester.tap(find.byKey(const Key('domain_tile_marriage')));
    await tester.pump();
    expect(selected, AppDomainId.marriage);
  });

  test('domainPostLine stays short and localized-ready', () {
    expect(domainPostLine(AppDomainId.marriage), 'Looking for marriage');
    expect(domainPostLine(AppDomainId.jobs), isNotEmpty);
  });
}
