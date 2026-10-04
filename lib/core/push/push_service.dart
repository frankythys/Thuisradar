import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_channels.dart';

/// Regelt FCM: het alarm-notificatiekanaal, tokenregistratie in device_tokens,
/// en het tonen van SOS-meldingen terwijl de app op de voorgrond staat.
class PushService {
  PushService(this._client, this._messaging, this._local);

  final SupabaseClient _client;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  StreamSubscription<String>? _tokenRefreshSub;

  StreamSubscription<RemoteMessage>? _foregroundSub;

  void dispose() {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
  }

  Future<void> init() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(PushChannels.sos);
    await android?.createNotificationChannel(PushChannels.places);
    await android?.createNotificationChannel(PushChannels.chat);

    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
  }

  /// Vraagt toestemming en bewaart het FCM-token voor deze gebruiker.
  Future<void> registerFor(String userId) async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) await _save(token, userId);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      (t) => _save(t, userId),
    );
  }

  /// Verwijdert het token bij uitloggen.
  Future<void> unregister() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    final token = await _messaging.getToken();
    if (token != null) {
      try {
        await _client.from('device_tokens').delete().eq('token', token);
      } on Exception catch (e) {
        debugPrint('Token verwijderen mislukt: $e');
      }
    }
    await _messaging.deleteToken();
  }

  Future<void> _save(String token, String userId) async {
    try {
      await _client.from('device_tokens').upsert({
        'token': token,
        'user_id': userId,
        'platform': 'android',
        'notification_version': 2,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } on Exception catch (e) {
      debugPrint('Token opslaan mislukt: $e');
    }
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final details = PushChannels.details(message.data['type'] as String?);

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
    );
  }
}
