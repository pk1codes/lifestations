import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/discovery_card.dart';
import 'firebase_bootstrap.dart';

class IdentityRepository {
  IdentityRepository({this.preferences, this.firestore, this.auth});

  final SharedPreferences? preferences;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  Future<void> save(Identity identity) async {
    final prefs = preferences;
    if (prefs != null) {
      await Future.wait(<Future<bool>>[
        prefs.setString('identity_name', identity.displayName.trim()),
        prefs.setString(
          'identity_phone',
          identity.whatsappNumber.replaceAll(RegExp(r'\D'), ''),
        ),
        prefs.setString('identity_city_id', identity.cityId),
        prefs.setString('identity_city_label', identity.cityLabel),
        prefs.setString('identity_language', identity.nativeLanguage),
        prefs.setBool('identity_phone_verified', identity.phoneVerified),
        prefs.setStringList('identity_photo_urls', identity.photoUrls),
      ]);
    }
    await sync(identity);
  }

  /// Syncs contact vault first (so like/unlock work even before full profile),
  /// then public identity when fields satisfy rules.
  Future<void> sync(Identity identity) async {
    await FirebaseBootstrap.waitUntilReady();
    if (!FirebaseBootstrap.ready) return;

    final authInstance = auth ?? FirebaseAuth.instance;
    var uid = authInstance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      final restored = await FirebaseBootstrap.waitForRestoredUser();
      uid = restored?.uid;
    }
    if (uid == null || uid.isEmpty) {
      try {
        uid = (await FirebaseBootstrap.ensureSignedIn()).uid;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Identity sync skipped (no auth): $error');
        }
        return;
      }
    }

    final digits = identity.whatsappNumber.replaceAll(RegExp(r'\D'), '');
    final database = firestore ?? FirebaseFirestore.instance;

    // Vault first — independent of validIdentity on the public user doc.
    if (digits.length >= 8) {
      await database.doc('users/$uid/private/contact').set({
        'whatsappNumber': digits,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!_canWritePublicIdentity(identity, uid)) return;

    await database.doc('users/$uid').set({
      'userId': uid,
      'displayName': identity.displayName.trim(),
      // Public user doc keeps empty contact — vault holds the number.
      'whatsappNumber': '',
      'cityId': identity.cityId,
      'cityLabel': identity.cityLabel,
      'nativeLanguage': identity.nativeLanguage,
      'photoUrls': identity.photoUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _canWritePublicIdentity(Identity identity, String uid) {
    final name = identity.displayName.trim();
    final city = identity.cityId.trim();
    final language = identity.nativeLanguage.trim();
    return name.length >= 2 &&
        city.length >= 2 &&
        language.length >= 2 &&
        language != 'Prefer not to say' &&
        uid.isNotEmpty;
  }
}
