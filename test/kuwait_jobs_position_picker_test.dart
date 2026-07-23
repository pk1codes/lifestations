import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/theme/app_theme.dart';
import 'package:flut_marriage/widgets/forms/kuwait_jobs_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('position picker can reach every required Kuwait trade', (
    tester,
  ) async {
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showKuwaitJobsPositionPicker(
                  context,
                  selected: {'Cook'},
                  accent: Colors.teal,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kuwait_jobs_position_list')), findsOneWidget);
    expect(
      find.textContaining('${KuwaitJobsProfile.trades.length} jobs A–Z'),
      findsOneWidget,
    );

    for (final trade in KuwaitJobsProfile.requiredTrades) {
      final item = find.byKey(Key('kuwait_job_$trade'));
      await tester.dragUntilVisible(
        item,
        find.byKey(const Key('kuwait_jobs_position_list')),
        const Offset(0, -280),
      );
      await tester.pumpAndSettle();
      expect(item, findsOneWidget, reason: trade);
    }

    final dd = find.byKey(const Key('kuwait_job_DD Planner'));
    await tester.dragUntilVisible(
      dd,
      find.byKey(const Key('kuwait_jobs_position_list')),
      const Offset(0, 280),
    );
    await tester.pumpAndSettle();
    await tester.tap(dd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use 2 positions'));
    await tester.pumpAndSettle();

    expect(result, containsAll(['Cook', 'DD Planner']));
  });
}
