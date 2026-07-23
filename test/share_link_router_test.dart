import 'dart:async';

import 'package:flut_marriage/services/share_link_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses public share routes from app links', () {
    expect(
      ShareLinkRouter.shareRouteFromLocation(
        'https://aaaa-4eee0.web.app/c/kuwait_jobs_abc123',
      ),
      '/c/kuwait_jobs_abc123',
    );
    expect(
      ShareLinkRouter.shareRouteFromLocation('/c/jobs_abc123'),
      '/c/jobs_abc123',
    );
    expect(
      ShareLinkRouter.shareRouteFromLocation('https://aaaa-4eee0.web.app/'),
      isNull,
    );
  });

  test('falls back to install referrer when no app link route exists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = ShareLinkRouter(
      getInitialUri: () async => null,
      incomingUriStream: const Stream<Uri>.empty(),
      consumeInstallReferrer: (_) async => 'rooms_abc123',
    );

    final route = await router.resolveInitialRoute(
      prefs: prefs,
      defaultRouteName: '/',
    );

    expect(route, '/c/rooms_abc123');
  });

  testWidgets('navigates when a new share link arrives while app is open', (
    tester,
  ) async {
    final stream = StreamController<Uri>.broadcast();
    addTearDown(stream.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    final router = ShareLinkRouter(
      getInitialUri: () async => null,
      incomingUriStream: stream.stream,
      consumeInstallReferrer: (_) async => null,
    );
    addTearDown(router.dispose);

    router.attach(navigatorKey);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Text(settings.name ?? '/', textDirection: TextDirection.ltr),
          ),
          settings: settings,
        ),
      ),
    );

    stream.add(Uri.parse('https://aaaa-4eee0.web.app/c/jobs_abc123'));
    await tester.pumpAndSettle();

    expect(find.text('/c/jobs_abc123'), findsOneWidget);
  });
}
