import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DiscoveryStore surfaces loading and error for empty feed', () async {
    final store = DiscoveryStore(AppDomainId.marriage);
    expect(store.status, SyncStatus.idle);

    store.beginRemoteSync();
    expect(store.status, SyncStatus.loading);

    store.failRemoteSync('Could not load. Try again.');
    expect(store.status, SyncStatus.error);
    expect(store.error, 'Could not load. Try again.');

    var retried = false;
    store.onRetry = () async {
      retried = true;
      store.load(const []);
    };
    await store.retryRemoteSync();
    expect(retried, isTrue);
    expect(store.status, SyncStatus.ready);
  });

  testWidgets('BrowseFeedError offers Try again', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowseFeedError(
            message: 'Could not load. Try again.',
            onRetry: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('Could not load. Try again.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('feed_retry')));
    expect(tapped, isTrue);
  });

  testWidgets('BrowseFeedLoading shows progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrowseFeedLoading())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });
}
