import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/public_share_card.dart';
import 'package:flut_marriage/screens/public_share_card_screen.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('public share route renders redacted card', (tester) async {
    final repo = ShareCardRepository()
      ..putMemory(
        const PublicShareCard(
          slug: 'marriage_demo123',
          active: true,
          ownerId: 'owner',
          domain: AppDomainId.marriage,
          sourceId: 'src',
          headline: 'Marriage · intentional',
          locationLabel: 'Mumbai & MMR',
        ),
      );
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: MaterialApp(
          initialRoute: '/c/marriage_demo123',
          routes: <String, WidgetBuilder>{
            '/c/marriage_demo123': (_) =>
                const PublicShareCardScreen(slug: 'marriage_demo123'),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Marriage · intentional'), findsOneWidget);
    expect(find.text('Mumbai & MMR'), findsOneWidget);
    expect(find.text('Marriage'), findsWidgets);
    expect(find.textContaining('never included'), findsOneWidget);
    expect(find.text('Explore safely'), findsOneWidget);
  });

  testWidgets('promoted share card explains Top badge', (tester) async {
    final repo = ShareCardRepository()
      ..putMemory(
        const PublicShareCard(
          slug: 'jobs_demo123',
          active: true,
          ownerId: 'owner',
          domain: AppDomainId.jobs,
          sourceId: 'src',
          headline: 'Driver',
          locationLabel: 'Delhi NCR',
          promoted: true,
          verified: true,
        ),
      );
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: const MaterialApp(
          home: PublicShareCardScreen(slug: 'jobs_demo123'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Self-attested ID'), findsOneWidget);
    expect(find.textContaining('boosted visibility'), findsOneWidget);
    expect(find.textContaining('not a check by us'), findsOneWidget);
  });

  testWidgets('missing share slug shows not found', (tester) async {
    await tester.pumpWidget(
      Provider.value(
        value: ShareCardRepository(),
        child: const MaterialApp(home: PublicShareCardScreen(slug: 'missing')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Link not found'), findsOneWidget);
  });
}
