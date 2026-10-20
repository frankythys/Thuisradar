import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/language/application/language_providers.dart';
import '../supabase/supabase_providers.dart';
import 'push_service.dart';

/// Mislukte `Firebase.initializeApp()` in main.dart, dan is er geen
/// Firebase-app: `FirebaseMessaging.instance` zou dan gooien, dus geen push.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    ref.watch(supabaseClientProvider),
    Firebase.apps.isEmpty ? null : FirebaseMessaging.instance,
    FlutterLocalNotificationsPlugin(),
    strings: () => ref.read(appLocalizationsProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
