import 'package:flut_marriage/widgets/forms/form_fields.dart';
import 'package:flut_marriage/widgets/onboarding/identity_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flut_marriage/state/app_stores.dart';

void main() {
  testWidgets('identity form uses shared city list labels', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => IdentityStore(prefs),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showIdentityForm(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CityDropdown), findsOneWidget);
    expect(find.text('Mumbai & MMR'), findsNothing);
    expect(find.text(cityLabels['mumbai']!), findsWidgets);
    expect(cityLabels.length, greaterThan(3));
  });
}
