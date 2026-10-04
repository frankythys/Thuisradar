import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Keep IDs and raw sound names in sync with the Edge Function payloads.
abstract final class PushChannels {
  // Android cannot change a channel's sound after creation.
  static const sos = AndroidNotificationChannel(
    'sos_alerts_v2',
    'SOS-alarmen',
    description: 'Dringende noodoproepen van je gezin',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('thuisradar_sos'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
  static const places = AndroidNotificationChannel(
    'places',
    'Plaatsen',
    description: 'Aankomst en vertrek bij plaatsen',
    importance: Importance.defaultImportance,
    playSound: true,
  );
  static const chat = AndroidNotificationChannel(
    'chat_messages',
    'Chatberichten',
    description: 'Nieuwe berichten van je gezin',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('thuisradar_message'),
  );

  static AndroidNotificationDetails details(String? type) {
    final channel = switch (type) {
      'sos' => sos,
      'chat' => chat,
      _ => places,
    };
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: type == 'sos' ? Priority.max : Priority.high,
      playSound: true,
      sound: channel.sound,
      audioAttributesUsage: channel.audioAttributesUsage,
      category: type == 'sos'
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.message,
    );
  }
}
