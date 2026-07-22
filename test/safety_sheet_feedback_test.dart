import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/safety_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flut_marriage/widgets/safety/safety_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSafety extends SafetyRepository {
  @override
  Future<void> report({
    required AppDomainId domain,
    required String targetId,
    required String reason,
  }) async {}

  @override
  Future<void> flagImage({
    required AppDomainId domain,
    required String targetId,
    required String reason,
    int photoSlot = 0,
  }) async {}

  @override
  Future<void> blockUser(String targetUid) async {}
}

void main() {
  testWidgets('block shows confirmation SnackBar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BlockStore(preferences: prefs)),
          ChangeNotifierProvider(
            create: (_) => DiscoveryStore(AppDomainId.marriage),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSafetySheet(
                  context,
                  domain: AppDomainId.marriage,
                  targetId: 'card1',
                  ownerId: 'owner1',
                  safety: _FakeSafety(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked'), findsOneWidget);
  });

  testWidgets('report post shows confirmation SnackBar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BlockStore(preferences: prefs)),
          ChangeNotifierProvider(
            create: (_) => DiscoveryStore(AppDomainId.marriage),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSafetySheet(
                  context,
                  domain: AppDomainId.jobs,
                  targetId: 'card2',
                  ownerId: 'owner2',
                  safety: _FakeSafety(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();

    expect(find.text('Report submitted'), findsOneWidget);
  });
}
