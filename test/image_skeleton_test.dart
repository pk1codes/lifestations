import 'package:flut_marriage/widgets/image_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ImageSkeleton renders a soft fill', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(width: 80, height: 80, child: ImageSkeleton()),
        ),
      ),
    );
    expect(find.byType(ImageSkeleton), findsOneWidget);
    expect(find.byType(ColoredBox), findsWidgets);
  });
}
