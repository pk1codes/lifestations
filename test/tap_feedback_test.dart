import 'package:flut_marriage/theme/app_theme.dart';
import 'package:flut_marriage/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme uses strong Material ripple feedback', () {
    final theme = buildTheme();
    expect(theme.splashFactory, InkRipple.splashFactory);
    expect(theme.splashColor, AppTapFeedback.splash);
    expect(theme.highlightColor, AppTapFeedback.highlight);
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(theme.iconButtonTheme.style?.overlayColor, isNotNull);
    expect(theme.filledButtonTheme.style?.overlayColor, isNotNull);
    expect(theme.navigationBarTheme.overlayColor, isNotNull);
  });

  testWidgets('AppInkWell is Material + InkWell with feedback enabled', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: AppInkWell(
            onTap: () => tapped = true,
            child: const SizedBox(
              width: 120,
              height: 48,
              child: Center(child: Text('Tap me')),
            ),
          ),
        ),
      ),
    );

    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.enableFeedback, isTrue);
    expect(ink.splashColor, AppTapFeedback.splash);
    expect(find.byType(Material), findsWidgets);

    await tester.tap(find.text('Tap me'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
