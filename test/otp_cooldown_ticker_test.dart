import 'package:flut_marriage/services/contact_service.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

int? _secondsFromCooldown(String? text) {
  if (text == null) return null;
  final match = RegExp(r'Try again in (\d+)s').firstMatch(text);
  return match == null ? null : int.parse(match.group(1)!);
}

void main() {
  testWidgets('OTP cooldown error ticks down every second', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final identity = IdentityStore(prefs);
    final throttle = OtpThrottle(
      preferences: prefs,
      cooldown: const Duration(seconds: 10),
    );
    expect(throttle.record(DateTime.now()), isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: identity)],
        child: MaterialApp(
          home: Scaffold(body: OtpSheet(throttle: throttle)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '9869610903');
    await tester.tap(find.text('Send SMS code'));
    await tester.pump();

    expect(find.textContaining('Try again in'), findsOneWidget);
    final first = _secondsFromCooldown(
      tester.widget<Text>(find.textContaining('Try again in')).data,
    );
    expect(first, isNotNull);
    expect(first!, greaterThan(5));

    await tester.pump(const Duration(seconds: 3));
    final second = _secondsFromCooldown(
      tester.widget<Text>(find.textContaining('Try again in')).data,
    );
    expect(second, isNotNull);
    expect(second!, lessThan(first), reason: 'countdown must decrease');
  });
}
