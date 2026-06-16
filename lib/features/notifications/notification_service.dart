import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../auth/data/repositories/auth_repository.dart';
import '../auth/providers.dart';

/// Background isolate handler – must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBgHandler(RemoteMessage message) async {
  // Background processing hook – we keep it minimal so FCM can show its own
  // system notification on Android.  Add custom analytics here if needed.
}

class NotificationService {
  NotificationService(this._auth);
  final AuthRepository _auth;

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Permission (Android 13+ + iOS).
    if (Platform.isAndroid && (await Permission.notification.isDenied)) {
      await Permission.notification.request();
    }
    await _fm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Local-notifications channel for foreground messages.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit     = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'scrolliq_default',
        'ScrollIQ alerts',
        description: 'Brain Score updates, leaderboard, streaks',
        importance: Importance.defaultImportance,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 3. Token capture & rotation.
    final token = await _fm.getToken();
    if (token != null) {
      await _saveToken(token);
    }
    _fm.onTokenRefresh.listen(_saveToken);

    // 4. Foreground listener – show as a local notification.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5. Background isolate handler.
    FirebaseMessaging.onBackgroundMessage(firebaseBgHandler);
  }

  Future<void> _saveToken(String token) async {
    try {
      await _auth.updateFcmToken(token);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to save FCM token: $e');
      }
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    final notif = m.notification;
    if (notif == null) return;
    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scrolliq_default',
          'ScrollIQ alerts',
          channelDescription: 'Brain Score updates, leaderboard, streaks',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Local-only welcome / streak notification (used as a fallback if the
  /// backend is not yet wired up).
  Future<void> showLocalReminder({
    required String title,
    required String body,
  }) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scrolliq_default',
          'ScrollIQ alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(authRepositoryProvider));
});
