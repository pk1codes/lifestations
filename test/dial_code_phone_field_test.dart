import 'package:flut_marriage/services/phone_number.dart';
import 'package:flut_marriage/widgets/forms/dial_code_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dial code is a dropdown defaulting to India', (tester) async {
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

    expect(find.byType(DropdownButtonFormField<PhoneDialCode>), findsOneWidget);
    expect(find.text('+91 India'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.enterText(find.byType(TextFormField), '9869610903');
    expect(phone.text, '9869610903');
  });

  testWidgets('user can pick Kuwait from dropdown', (tester) async {
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

    await tester.tap(find.byType(DropdownButtonFormField<PhoneDialCode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+965 Kuwait').last);
    await tester.pumpAndSettle();

    expect(dial, PhoneDialCode.kuwait);
    expect(find.text('+965 Kuwait'), findsWidgets);
  });
}
