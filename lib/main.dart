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
import 'services/discovery_feed_cache.dart';
import 'services/domain_repository.dart';
import 'services/firebase_bootstrap.dart';
import 'services/listing_image_cache.dart';
import 'services/listing_publisher.dart';
import 'services/owned_listing_cache.dart';
import 'services/push_service.dart';
import 'services/seed_repository.dart';
import 'services/share_card_repository.dart';
import 'services/share_link_router.dart';
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
  final navigatorKey = GlobalKey<NavigatorState>();
  final shareLinkRouter = ShareLinkRouter();
  final feedCache = DiscoveryFeedCache(prefs);
  final domainController = DomainController(prefs);
  final stores = <AppDomainId, DiscoveryStore>{
    for (final domain in AppDomainId.values)
      domain: DiscoveryStore(domain, feedCache: feedCache),
  };
  const seeds = SeedRepository();
  final allowSeeds = FeatureFlags.allowSeedsAtStartup;
  // Local-first: last live feed → else seeds (when allowed).
  for (final entry in stores.entries) {
    final cached = feedCache.read(entry.key);
    if (cached.isNotEmpty) {
      entry.value.load(cached);
      ListingImageCache.warmCards(cached);
    } else if (allowSeeds) {
      entry.value.load(seeds.forDomain(entry.key));
    }
  }

  Future<void> loadRemoteFeeds() async {
    if (!FirebaseBootstrap.ready) return;
    for (final store in stores.values) {
      store.beginRemoteSync();
    }
    try {
      await FirebaseBootstrap.ensureSignedIn();
    } catch (_) {
      // Stay on local/cached live cards until the user can sign in.
      // Never inject bundled demos in release.
      for (final store in stores.values) {
        if (store.status == SyncStatus.loading) store.markReady();
      }
      return;
    }
    try {
      final engine = ScopedSyncEngine(FirestoreDomainRepository());
      for (final entry in stores.entries) {
        final local = entry.value.cards;
        final merged = await engine.merge(domain: entry.key, local: local);
        final hasLive = merged.any((card) => !DiscoveryFeedCache.isDemo(card));
        if (hasLive) {
          entry.value.applyRemote(ScopedSyncEngine.withoutDemos(merged));
        } else if (FeatureFlags.allowBundledSeeds(remoteFeedEmpty: true)) {
          entry.value.load(
            merged.isEmpty ? seeds.forDomain(entry.key) : merged,
          );
        } else {
          // Release: empty remote → empty feed (drop any leftover demos).
          entry.value.load(ScopedSyncEngine.withoutDemos(merged));
        }
      }
    } catch (_) {
      for (final store in stores.values) {
        if (store.cards.isEmpty) {
          store.failRemoteSync();
        } else if (store.status == SyncStatus.loading) {
          store.markReady();
        }
      }
    }
  }

  // Pull-to-refresh / resume / retry always reload every domain feed.
  for (final store in stores.values) {
    store.onRetry = loadRemoteFeeds;
  }

  unawaited(
    FirebaseBootstrap.initialize().then((_) async {
      await loadRemoteFeeds();
      // First auth event can be null before IndexedDB restore; reload once
      // a real session appears so Browse is not stuck on demos.
      var lastUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      FirebaseAuth.instance.authStateChanges().listen((user) {
        final uid = user?.uid ?? '';
        if (uid.isEmpty || uid == lastUid) return;
        lastUid = uid;
        unawaited(loadRemoteFeeds());
      });
      final uid = FirebaseAuth.instance.currentUser?.uid;
      unawaited(PushService().initialize(uid: uid));
      // Likes/identity hydrate from HomeShell once auth + bootstrap are ready.
    }),
  );

  final shareRepo = ShareCardRepository();
  final initialRoute = await shareLinkRouter.resolveInitialRoute(
    prefs: prefs,
    defaultRouteName: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );
  runApp(
    FlutMarriageApp(
      preferences: prefs,
      domainController: domainController,
      discoveryStores: stores,
      shareRepository: shareRepo,
      initialRoute: initialRoute,
      navigatorKey: navigatorKey,
    ),
  );
  shareLinkRouter.attach(navigatorKey);
}

class FlutMarriageApp extends StatelessWidget {
  const FlutMarriageApp({
    required this.preferences,
    required this.domainController,
    required this.discoveryStores,
    this.shareRepository,
    this.initialRoute = '/',
    this.navigatorKey,
    super.key,
  });

  final SharedPreferences preferences;
  final DomainController domainController;
  final Map<AppDomainId, DiscoveryStore> discoveryStores;
  final ShareCardRepository? shareRepository;
  final String initialRoute;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    final repository = shareRepository ?? ShareCardRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: domainController),
        ChangeNotifierProvider(create: (_) => IdentityStore(preferences)),
        ChangeNotifierProvider(
          create: (_) => LikesStore(preferences: preferences),
        ),
        ChangeNotifierProvider(create: (_) => LocaleController(preferences)),
        ChangeNotifierProvider(create: (_) => ProfileStore(preferences)),
        ChangeNotifierProvider(
          create: (_) => JobsOfferStore(preferences: preferences),
        ),
        ChangeNotifierProvider(
          create: (_) => KuwaitJobsOfferStore(preferences: preferences),
        ),
        ChangeNotifierProvider(
          create: (_) => RoomsOfferStore(preferences: preferences),
        ),
        ChangeNotifierProvider(
          create: (_) => BikesOfferStore(preferences: preferences),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeHelpOfferStore(preferences: preferences),
        ),
        ChangeNotifierProvider(create: (_) => OwnedListingCache(preferences)),
        ChangeNotifierProvider(create: (_) => MatchPreferencesStore()),
        ChangeNotifierProvider(create: (_) => JobsDiscoverPrefsStore()),
        ChangeNotifierProvider(create: (_) => KuwaitJobsDiscoverPrefsStore()),
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
          navigatorKey: navigatorKey,
          title: 'Life Stations',
          theme: buildTheme(),
          locale: locale.localeCode == null ? null : Locale(locale.localeCode!),
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: initialRoute,
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
