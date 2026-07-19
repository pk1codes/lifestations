import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Web and Android configs are live (project aaaa-4eee0). iOS/macOS still
/// carry placeholders until GoogleService-Info.plist is generated via
/// `flutterfire configure`.
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      TargetPlatform.fuchsia => android,
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyA_EpGL38TKpHauLMpN4fHjIdBOz-fnbjA',
    appId: '1:555405657259:web:bf936ecdb322b86c52a3ee',
    messagingSenderId: '555405657259',
    projectId: 'aaaa-4eee0',
    authDomain: 'aaaa-4eee0.firebaseapp.com',
    storageBucket: 'aaaa-4eee0.firebasestorage.app',
    measurementId: 'G-XFGJYSE3BJ',
  );
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDQjniEqhJ-PaDPXVXUFaxlsu9fkgUwATY',
    appId: '1:555405657259:android:4c3c69def884527b52a3ee',
    messagingSenderId: '555405657259',
    projectId: 'aaaa-4eee0',
    storageBucket: 'aaaa-4eee0.firebasestorage.app',
  );
  static const ios = FirebaseOptions(
    apiKey: 'replace-with-ios-api-key',
    appId: '1:000000000000:ios:replace',
    messagingSenderId: '000000000000',
    projectId: 'replace-with-project-id',
    storageBucket: 'replace-with-project-id.appspot.com',
    iosBundleId: 'com.matchmaker.flutMarriage',
  );
  static const macos = ios;
  static const windows = web;
  static const linux = web;
}
