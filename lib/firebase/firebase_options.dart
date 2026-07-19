import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Placeholder configuration. Replace with `flutterfire configure` output.
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
    apiKey: 'replace-with-web-api-key',
    appId: '1:000000000000:web:replace',
    messagingSenderId: '000000000000',
    projectId: 'replace-with-project-id',
    authDomain: 'replace-with-project-id.firebaseapp.com',
    storageBucket: 'replace-with-project-id.appspot.com',
  );
  static const android = FirebaseOptions(
    apiKey: 'replace-with-android-api-key',
    appId: '1:000000000000:android:replace',
    messagingSenderId: '000000000000',
    projectId: 'replace-with-project-id',
    storageBucket: 'replace-with-project-id.appspot.com',
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
