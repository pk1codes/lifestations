import 'package:flut_marriage/widgets/forms/save_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photosNeededLabel covers common cases', () {
    expect(photosNeededLabel(have: 0, need: 1), 'Add a photo');
    expect(photosNeededLabel(have: 0, need: 2), 'Add 2 photos');
    expect(photosNeededLabel(have: 1, need: 2), 'Add 1 more photo');
    expect(photosNeededLabel(have: 2, need: 4), 'Add 2 more photos');
    expect(photosNeededLabel(have: 4, need: 4), '');
  });

  testWidgets('SaveGateButton stays disabled until missing is empty', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveGateButton(
            missing: const ['Add a photo'],
            accent: Colors.pink,
            onSave: () async => saved = true,
          ),
        ),
      ),
    );

    expect(find.text('Add a photo'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save_gate_button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('save_gate_button')));
    expect(saved, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveGateButton(
            missing: const [],
            accent: Colors.pink,
            onSave: () async => saved = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('save_gate_button')));
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('SaveGateButton shows Saving feedback while await runs', (
    tester,
  ) async {
    var finish = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveGateButton(
            missing: const [],
            accent: Colors.teal,
            onSave: () async {
              while (!finish) {
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('save_gate_button')));
    await tester.pump();
    expect(find.byKey(const Key('save_gate_busy')), findsOneWidget);
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    finish = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save_gate_busy')), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });
}
