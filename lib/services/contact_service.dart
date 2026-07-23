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

Uri buildTelegramNativeUri(String handle, {String? message}) {
  final cleaned = cleanTelegramHandle(handle);
  return Uri(
    scheme: 'tg',
    host: 'resolve',
    queryParameters: {
      'domain': cleaned,
      if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
    },
  );
}

Uri buildTelegramHttpsUri(String handle, {String? message}) {
  final cleaned = cleanTelegramHandle(handle);
  return Uri.https('t.me', '/$cleaned', {
    if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
  });
}

/// Official phone deep link: `tg://resolve?phone=&text=` (draft prefill).
Uri buildTelegramPhoneNativeUri(String digits, {String? message}) {
  final cleaned = cleanWhatsAppDigits(digits);
  return Uri(
    scheme: 'tg',
    host: 'resolve',
    queryParameters: {
      'phone': cleaned,
      if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
    },
  );
}

/// Universal phone link. Prefill via `text` is best-effort on clients.
Uri buildTelegramPhoneHttpsUri(String digits, {String? message}) {
  final cleaned = cleanWhatsAppDigits(digits);
  return Uri.https('t.me', '/+$cleaned', {
    if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
  });
}

Map<String, dynamic> _asStringKeyedMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
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
        final result = await _functions.httpsCallable('unlockContact').call({
          'domainId': slug,
          'targetUid': targetUid,
        });
        final data = _asStringKeyedMap(result.data);
        if (data['found'] != true) return null;
        final number = cleanWhatsAppDigits('${data['whatsappNumber'] ?? ''}');
        if (number.length < 8) return null;
        final handleRaw = '${data['telegramHandle'] ?? ''}'.trim();
        return PrivateContact(
          whatsappNumber: number,
          telegramHandle: handleRaw.isEmpty ? null : handleRaw,
        );
      } on FirebaseFunctionsException catch (error) {
        if (kDebugMode) {
          debugPrint(
            'unlockContact failed (${error.code}): ${error.message}',
          );
        }
        if (error.code == 'permission-denied') {
          throw StateError(error.message ?? 'Mutual interest required');
        }
        if (error.code == 'unauthenticated') {
          throw StateError('Sign in required');
        }
        if (error.code == 'failed-precondition' ||
            error.message?.toLowerCase().contains('app check') == true) {
          throw StateError('App Check blocked unlock. Update the app.');
        }
        throw StateError(error.message ?? 'Could not unlock contact');
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
    // HTTPS first — more reliable on Android 11+ than whatsapp:// alone.
    final uris = <Uri>[
      buildWhatsAppApiUri(cleaned, message: text),
      buildWhatsAppHttpsUri(cleaned, message: text),
      if (!kIsWeb) buildWhatsAppNativeUri(cleaned, message: text),
    ];
    for (final uri in uris) {
      if (await _launchExternal(uri)) return true;
    }
    // Last resort so the user can still start the chat manually.
    try {
      await Clipboard.setData(
        ClipboardData(text: '+$cleaned\n$text'),
      );
    } catch (_) {}
    return false;
  }

  /// Opens Telegram to [handle] or [phoneDigits] with a draft message when possible.
  ///
  /// Vault currently stores the shared phone (same as WhatsApp). Username is
  /// optional; phone deep links use official `tg://resolve?phone=&text=`.
  Future<bool> openTelegram({
    String? handle,
    String? phoneDigits,
    String? domainLabel,
    String? message,
  }) async {
    final text = (message ?? contactOpenMessage(domainLabel: domainLabel))
        .trim();
    final cleanedHandle = cleanTelegramHandle(handle ?? '');
    final cleanedPhone = cleanWhatsAppDigits(phoneDigits ?? '');

    final uris = <Uri>[];
    if (cleanedHandle.length >= 3) {
      if (!kIsWeb) {
        uris.add(buildTelegramNativeUri(cleanedHandle, message: text));
      }
      uris.add(buildTelegramHttpsUri(cleanedHandle, message: text));
    }
    if (cleanedPhone.length >= 8) {
      if (!kIsWeb) {
        uris.add(buildTelegramPhoneNativeUri(cleanedPhone, message: text));
      }
      uris.add(buildTelegramPhoneHttpsUri(cleanedPhone, message: text));
    }
    if (uris.isEmpty) return false;

    // Clipboard fallback for clients that open chat but ignore `text`.
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}

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
      LaunchMode.externalApplication,
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('launchUrl failed ($mode) $uri: $error');
        }
      }
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
