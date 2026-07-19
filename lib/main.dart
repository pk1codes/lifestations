import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/feature_flags.dart';
import 'l10n/app_localizations.dart';
import 'models/app_domain.dart';
import 'screens/home_shell.dart';
import 'screens/public_share_card_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/account_services.dart';
import 'services/domain_repository.dart';
import 'services/firebase_bootstrap.dart';
import 'services/listing_publisher.dart';
import 'services/push_service.dart';
import 'services/seed_repository.dart';
import 'services/share_card_repository.dart';
import 'services/share_service.dart';
import 'state/app_stores.dart';
import 'state/domain_profile_stores.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  PaintingBinding.instance.imageCache
    ..maximumSize = 40
    ..maximumSizeBytes = 12 * 1024 * 1024;

  final prefs = await SharedPreferences.getInstance();
  final domainController = DomainController(prefs);
  final stores = <AppDomainId, DiscoveryStore>{
    for (final domain in AppDomainId.values) domain: DiscoveryStore(domain),
  };
  const seeds = SeedRepository();
  final allowSeeds = FeatureFlags.allowSeedsAtStartup;
  if (allowSeeds) {
    for (final entry in stores.entries) {
      entry.value.load(seeds.forDomain(entry.key));
    }
  }

  unawaited(
    FirebaseBootstrap.initialize().then((_) async {
      if (!FirebaseBootstrap.ready) return;
      final engine = ScopedSyncEngine(FirestoreDomainRepository());
      for (final entry in stores.entries) {
        final local = entry.value.cards;
        final merged = await engine.merge(domain: entry.key, local: local);
        if (FeatureFlags.allowBundledSeeds(remoteFeedEmpty: merged.isEmpty)) {
          entry.value.load(
            merged.isEmpty ? seeds.forDomain(entry.key) : merged,
          );
        } else {
          entry.value.load(merged);
        }
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      unawaited(PushService().initialize(uid: uid));
    }),
  );

  final shareRepo = ShareCardRepository();
  runApp(
    FlutMarriageApp(
      preferences: prefs,
      domainController: domainController,
      discoveryStores: stores,
      shareRepository: shareRepo,
    ),
  );
}

class FlutMarriageApp extends StatelessWidget {
  const FlutMarriageApp({
    required this.preferences,
    required this.domainController,
    required this.discoveryStores,
    this.shareRepository,
    super.key,
  });

  final SharedPreferences preferences;
  final DomainController domainController;
  final Map<AppDomainId, DiscoveryStore> discoveryStores;
  final ShareCardRepository? shareRepository;

  @override
  Widget build(BuildContext context) {
    final repository = shareRepository ?? ShareCardRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: domainController),
        ChangeNotifierProvider(create: (_) => IdentityStore(preferences)),
        ChangeNotifierProvider(create: (_) => LikesStore()),
        ChangeNotifierProvider(create: (_) => LocaleController(preferences)),
        ChangeNotifierProvider(create: (_) => ProfileStore()),
        ChangeNotifierProvider(create: (_) => JobsProfileStore()),
        ChangeNotifierProvider(create: (_) => RoomsOfferStore()),
        ChangeNotifierProvider(create: (_) => BikesOfferStore()),
        ChangeNotifierProvider(create: (_) => HomeHelpOfferStore()),
        ChangeNotifierProvider(create: (_) => MatchPreferencesStore()),
        ChangeNotifierProvider(create: (_) => JobsDiscoverPrefsStore()),
        ChangeNotifierProvider(
          create: (_) => BlockStore(
            preferences: preferences,
            onBlock: (id) {
              for (final store in discoveryStores.values) {
                store.block(id);
              }
            },
          ),
        ),
        ChangeNotifierProvider(create: (_) => TrustService()),
        ChangeNotifierProvider(create: (_) => BillingService()),
        Provider<ShareCardRepository>.value(value: repository),
        Provider<ShareService>(create: (_) => ShareService(repository)),
        Provider<ListingPublisher>(
          create: (_) => ListingPublisher(shareRepository: repository),
        ),
        ChangeNotifierProxyProvider<DomainController, DiscoveryStore>(
          create: (_) => discoveryStores[domainController.selected]!,
          update: (_, domain, previous) => discoveryStores[domain.selected]!,
        ),
      ],
      child: Consumer<LocaleController>(
        builder: (context, locale, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flut Marriage',
          theme: buildTheme(),
          locale: locale.localeCode == null ? null : Locale(locale.localeCode!),
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          onGenerateRoute: (settings) {
            final path =
                Uri.tryParse(settings.name ?? '/')?.pathSegments ??
                const <String>[];
            if (path.length == 2 && path.first == 'c') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => PublicShareCardScreen(slug: path.last),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const HomeShell(),
            );
          },
        ),
      ),
    );
  }
}
