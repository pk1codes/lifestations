import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty feed names domain and offers next steps', (tester) async {
    var cleared = false;
    var reset = false;
    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyBrowseFeed(
            domainLabel: 'Marriage',
            hasFilters: true,
            onClearFilters: () => cleared = true,
            onReset: () => reset = true,
            onChangeDomain: () => changed = true,
          ),
        ),
      ),
    );

    expect(
      find.text('Nothing in Marriage matches your filters.'),
      findsOneWidget,
    );
    expect(find.text('Clear filters'), findsOneWidget);
    expect(find.text('Show again'), findsOneWidget);
    expect(find.text('Change domain'), findsOneWidget);

    await tester.tap(find.byKey(const Key('empty_clear_filters')));
    await tester.tap(find.text('Show again'));
    await tester.tap(find.byKey(const Key('empty_change_domain')));
    expect(cleared, isTrue);
    expect(reset, isTrue);
    expect(changed, isTrue);
  });

  testWidgets('empty feed without filters omits clear CTA', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyBrowseFeed(
            domainLabel: 'Jobs',
            hasFilters: false,
            onReset: _noop,
            onChangeDomain: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Nothing in Jobs right now.'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });
}

void _noop() {}
