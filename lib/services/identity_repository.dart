import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      ]);
    }
    await sync(identity);
  }

  Future<void> sync(Identity identity) async {
    if (!FirebaseBootstrap.ready) return;
    final authInstance = auth ?? FirebaseAuth.instance;
    final uid = authInstance.currentUser?.uid;
    if (uid == null) return;
    final digits = identity.whatsappNumber.replaceAll(RegExp(r'\D'), '');
    final database = firestore ?? FirebaseFirestore.instance;
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
    if (digits.length >= 8) {
      await database.doc('users/$uid/private/contact').set({
        'whatsappNumber': digits,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
