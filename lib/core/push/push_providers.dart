import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/language/application/language_providers.dart';
import '../supabase/supabase_providers.dart';
import 'push_service.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    ref.watch(supabaseClientProvider),
    FirebaseMessaging.instance,
    FlutterLocalNotificationsPlugin(),
    strings: () => ref.read(appLocalizationsProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
