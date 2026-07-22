import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/widgets/expandable_domain_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ExpandableDomainSection shows count when collapsed', (
    tester,
  ) async {
    final policy = AppDomains.byId(AppDomainId.marriage);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpandableDomainSection(
            domain: policy,
            count: 3,
            icon: Icons.favorite,
            initiallyExpanded: false,
            children: const [Text('card-a'), Text('card-b')],
          ),
        ),
      ),
    );

    expect(find.text('Marriage'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('card-a'), findsNothing);

    await tester.tap(find.byKey(const Key('domain_section_header_marriage')));
    await tester.pumpAndSettle();
    expect(find.text('card-a'), findsOneWidget);
  });
}
