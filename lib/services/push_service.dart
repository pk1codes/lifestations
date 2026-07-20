import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_bootstrap.dart';

/// Best-effort FCM setup. Never blocks UI; never logs tokens in release.
class PushService {
  PushService({
    this.messaging,
    FlutterLocalNotificationsPlugin? local,
    this.firestore,
  }) : _local = local ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'flut_likes_high';
  final FirebaseMessaging? messaging;
  final FlutterLocalNotificationsPlugin _local;
  final FirebaseFirestore? firestore;

  FirebaseMessaging get _messaging {
    final injected = messaging;
    if (injected != null) return injected;
    if (!FirebaseBootstrap.ready) {
      throw StateError('Messaging unavailable until bootstrap succeeds');
    }
    return FirebaseMessaging.instance;
  }

  FirebaseFirestore get _db {
    final injected = firestore;
    if (injected != null) return injected;
    if (!FirebaseBootstrap.ready) {
      throw StateError('Firestore unavailable until bootstrap succeeds');
    }
    return FirebaseFirestore.instance;
  }

  Future<void> initialize({required String? uid}) async {
    if (kIsWeb || uid == null || uid.isEmpty || !FirebaseBootstrap.ready) {
      return;
    }
    if (!(defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      const channel = AndroidNotificationChannel(
        channelId,
        'Likes',
        description: 'High-priority mutual interest alerts',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.doc('users/$uid/private/push').set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (error) {
      if (kDebugMode) debugPrint('PushService skipped: $error');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    // Never include contact details in notification body.
    await _local.show(
      notification.hashCode,
      notification.title ?? 'Update',
      notification.body ?? 'Someone is interested in your post',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Likes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
