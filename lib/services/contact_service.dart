import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_domain.dart';
import 'firebase_bootstrap.dart';

class PrivateContact {
  const PrivateContact({required this.whatsappNumber, this.telegramHandle});
  final String whatsappNumber;
  final String? telegramHandle;
}

class ContactService {
  ContactService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Prefer callable unlock (same-domain + phone). Falls back to local mutual check only in debug.
  Future<PrivateContact?> unlock({
    required AppDomainId domain,
    required String targetUid,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.phoneNumber == null) {
      throw StateError('Phone verification is required');
    }
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    if (FirebaseBootstrap.ready) {
      try {
        final result = await _functions
            .httpsCallable('unlockContact')
            .call<Map<String, dynamic>>({
              'domainId': slug,
              'targetUid': targetUid,
            });
        final data = result.data;
        if (data['found'] != true) return null;
        final number = (data['whatsappNumber'] as String? ?? '').replaceAll(
          RegExp(r'\D'),
          '',
        );
        if (number.length < 8) return null;
        return PrivateContact(
          whatsappNumber: number,
          telegramHandle: data['telegramHandle'] as String?,
        );
      } catch (error) {
        if (kDebugMode) debugPrint('unlockContact callable failed: $error');
        rethrow;
      }
    }
    // Offline/debug: never invent production contacts.
    if (kReleaseMode) return null;
    final outbound = await _firestore
        .doc('domains/$slug/likes/${user.uid}/outbound/$targetUid')
        .get();
    final inbound = await _firestore
        .doc('domains/$slug/likes/${user.uid}/inbound/$targetUid')
        .get();
    if (!outbound.exists || !inbound.exists) {
      throw StateError('Mutual interest is required');
    }
    return null;
  }

  Future<bool> openWhatsApp(String digits) async {
    final cleaned = digits.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 8) return false;
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openTelegram(String handle) async {
    final cleaned = handle.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (cleaned.length < 3) return false;
    final uri = Uri.parse('https://t.me/$cleaned');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class OtpThrottle {
  OtpThrottle({
    this.cooldown = const Duration(seconds: 60),
    this.preferences,
    this.prefsKey = 'otp_last_sent_ms',
  }) {
    final stored = preferences?.getInt(prefsKey);
    if (stored != null) {
      _lastSent = DateTime.fromMillisecondsSinceEpoch(stored);
    }
  }

  final Duration cooldown;
  final SharedPreferences? preferences;
  final String prefsKey;
  DateTime? _lastSent;

  Duration remaining(DateTime now) {
    final last = _lastSent;
    if (last == null) return Duration.zero;
    final value = cooldown - now.difference(last);
    return value.isNegative ? Duration.zero : value;
  }

  bool record(DateTime now) {
    if (remaining(now) > Duration.zero) return false;
    _lastSent = now;
    try {
      preferences?.setInt(prefsKey, now.millisecondsSinceEpoch);
    } catch (_) {}
    return true;
  }
}
