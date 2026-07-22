import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('coming soon has no dead waitlist CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ComingSoonView(domain: AppDomains.rooms)),
    );

    expect(find.textContaining('tuning up'), findsOneWidget);
    expect(find.text('Join the waitlist'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
