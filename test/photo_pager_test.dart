import 'package:flut_marriage/widgets/photo_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery shows dots only for multiple photos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: PhotoGalleryPager(
              children: [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PhotoPageDots), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: PhotoGalleryPager(
              children: [ColoredBox(color: Colors.red)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PhotoPageDots), findsNothing);
  });

  testWidgets('extra badge shows +N', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PhotoExtraBadge(extraCount: 2)),
      ),
    );
    expect(find.text('+2'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PhotoExtraBadge(extraCount: 0)),
      ),
    );
    expect(find.text('+0'), findsNothing);
  });
}
