import 'package:flut_marriage/services/phone_number.dart';
import 'package:flut_marriage/widgets/forms/dial_code_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dial code chips default to India with national digits only', (
    tester,
  ) async {
    var dial = PhoneDialCode.india;
    final phone = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialCodePhoneField(
            dial: dial,
            controller: phone,
            onDialChanged: (code) => dial = code,
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNWidgets(PhoneDialCode.all.length));
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('+965'), findsOneWidget);
    expect(find.text('India +91'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<PhoneDialCode>), findsNothing);

    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('9869610903'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '9869610903');
    expect(phone.text, '9869610903');
  });

  testWidgets('user can pick Kuwait chip', (tester) async {
    var dial = PhoneDialCode.india;
    final phone = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DialCodePhoneField(
                dial: dial,
                controller: phone,
                onDialChanged: (code) => setState(() => dial = code),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('dial_965')));
    await tester.pumpAndSettle();

    expect(dial, PhoneDialCode.kuwait);
    expect(find.text('Kuwait +965'), findsOneWidget);
  });
}
