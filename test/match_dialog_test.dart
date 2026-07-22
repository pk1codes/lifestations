import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('match Continue opens Likes tab', (tester) async {
    SharedPreferences.setMockInitialValues({'domain_coach_seen': true});
    final prefs = await SharedPreferences.getInstance();
    final domains = DomainController(prefs);
    expect(domains.selectedTab, 0);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: domains,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMatchDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Both interested'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Both interested'), findsNothing);
    expect(domains.selectedTab, 1);
  });

  testWidgets('match Later dismisses without changing tab', (tester) async {
    SharedPreferences.setMockInitialValues({'domain_coach_seen': true});
    final prefs = await SharedPreferences.getInstance();
    final domains = DomainController(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: domains,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMatchDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(domains.selectedTab, 0);
  });
}
