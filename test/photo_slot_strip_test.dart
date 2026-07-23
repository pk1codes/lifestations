import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/widgets/forms/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('photo slot strip shows Add photo on empty required slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoSlotStrip(
            urls: const <String>[],
            minimum: 2,
            maximum: 4,
            accent: AppDomains.rooms.color,
            softAccent: AppDomains.rooms.softColor,
            onPick: (_) async => false,
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Add 2 or more'), findsOneWidget);
    expect(find.text('Add photo'), findsNWidgets(2));
    expect(find.text('Need'), findsNothing);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsWidgets);
  });

  testWidgets('filled slot shows compact remove control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoSlotStrip(
            urls: const <String>['local://demo'],
            minimum: 1,
            maximum: 3,
            accent: AppDomains.marriage.color,
            softAccent: AppDomains.marriage.softColor,
            onPick: (_) async => true,
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Add photo'), findsNothing);
    expect(find.text('Need'), findsNothing);

    final remove = find.byKey(const Key('photo_slot_remove'));
    expect(remove, findsOneWidget);
    final size = tester.getSize(remove);
    expect(size.width, 22);
    expect(size.height, 22);
  });
}
