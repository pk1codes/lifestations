import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_domain.dart';
import 'firebase_bootstrap.dart';

class PrivateContact {
  const PrivateContact({required this.whatsappNumber, this.telegramHandle});
  final String whatsappNumber;
  final String? telegramHandle;
}

/// Short starter so the user only has to tap Send in WhatsApp / Telegram.
String contactOpenMessage({String? domainLabel}) {
  final domain = domainLabel?.trim() ?? '';
  if (domain.isNotEmpty) {
    return 'Hi, I found you on Life Stations ($domain).';
  }
  return 'Hi, I found you on Life Stations.';
}

/// Digits-only E.164 without `+` (e.g. `919869610903`).
String cleanWhatsAppDigits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

String cleanTelegramHandle(String raw) =>
    raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

/// Prefer installed WhatsApp; `wa.me` / api.whatsapp.com prefills the chat.
Uri buildWhatsAppNativeUri(String digits, {required String message}) {
  final cleaned = cleanWhatsAppDigits(digits);
  return Uri(
    scheme: 'whatsapp',
    host: 'send',
    queryParameters: {'phone': cleaned, 'text': message},
  );
}

Uri buildWhatsAppHttpsUri(String digits, {required String message}) {
  final cleaned = cleanWhatsAppDigits(digits);
  return Uri.https('wa.me', '/$cleaned', {'text': message});
}

/// Android often resolves this to the WhatsApp app (not Chrome).
Uri buildWhatsAppApiUri(String digits, {required String message}) {
  final cleaned = cleanWhatsAppDigits(digits);
  return Uri.https('api.whatsapp.com', '/send', {
    'phone': cleaned,
    'text': message,
  });
}

Uri buildTelegramNativeUri(String handle) {
  final cleaned = cleanTelegramHandle(handle);
  return Uri(
    scheme: 'tg',
    host: 'resolve',
    queryParameters: {'domain': cleaned},
  );
}

Uri buildTelegramHttpsUri(String handle) {
  final cleaned = cleanTelegramHandle(handle);
  return Uri.https('t.me', '/$cleaned');
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
    final slug = AppDomains.byId(domain).slug;
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

  /// Opens the phone WhatsApp app (or web) to [digits] with a ready-to-send message.
  Future<bool> openWhatsApp(
    String digits, {
    String? domainLabel,
    String? message,
  }) async {
    final cleaned = cleanWhatsAppDigits(digits);
    if (cleaned.length < 8) return false;
    final text = (message ?? contactOpenMessage(domainLabel: domainLabel))
        .trim();
    final uris = <Uri>[
      if (!kIsWeb) buildWhatsAppNativeUri(cleaned, message: text),
      buildWhatsAppApiUri(cleaned, message: text),
      buildWhatsAppHttpsUri(cleaned, message: text),
    ];
    for (final uri in uris) {
      if (await _launchExternal(uri)) return true;
    }
    // Last resort so the user can still start the chat manually.
    try {
      await Clipboard.setData(ClipboardData(text: '+$cleaned'));
    } catch (_) {}
    return false;
  }

  /// Opens Telegram to [handle]. Message is copied so the user can paste & send
  /// (Telegram user chats do not support WhatsApp-style URL prefills).
  Future<bool> openTelegram(
    String handle, {
    String? domainLabel,
    String? message,
  }) async {
    final cleaned = cleanTelegramHandle(handle);
    if (cleaned.length < 3) return false;
    final text = (message ?? contactOpenMessage(domainLabel: domainLabel))
        .trim();
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
    final uris = <Uri>[
      if (!kIsWeb) buildTelegramNativeUri(cleaned),
      buildTelegramHttpsUri(cleaned),
    ];
    for (final uri in uris) {
      if (await _launchExternal(uri)) return true;
    }
    return false;
  }

  /// Try hard to leave the app / browser and open the chat client.
  Future<bool> _launchExternal(Uri uri) async {
    if (kIsWeb) {
      try {
        return await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } catch (error) {
        if (kDebugMode) debugPrint('launch web failed: $error');
        return false;
      }
    }
    // Prefer non-browser so Android opens WhatsApp/Telegram, not Chrome.
    for (final mode in <LaunchMode>[
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.externalApplication,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (_) {}
    }
    return false;
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
