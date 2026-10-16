import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/l10n.dart';

/// Keep IDs and raw sound names in sync with the Edge Function payloads.
/// De namen volgen de taal van de app; Android werkt de naam van een bestaand
/// kanaal bij, het id en het geluid niet.
abstract final class PushChannels {
  // Android cannot change a channel's sound after creation.
  static AndroidNotificationChannel sos(AppLocalizations l10n) => AndroidNotificationChannel(
    'sos_alerts_v2',
    l10n.channelSos,
    description: l10n.channelSosDescription,
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('thuisradar_sos'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
  // Nieuw id: Android kan het geluid van een bestaand kanaal niet wijzigen.
  static AndroidNotificationChannel places(AppLocalizations l10n) => AndroidNotificationChannel(
    'places_v2',
    l10n.channelPlaces,
    description: l10n.channelPlacesDescription,
    importance: Importance.high,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('thuisradar_arrival'),
  );
  static AndroidNotificationChannel chat(AppLocalizations l10n) => AndroidNotificationChannel(
    'chat_messages',
    l10n.channelChat,
    description: l10n.channelChatDescription,
    importance: Importance.high,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('thuisradar_message'),
  );

  static AndroidNotificationDetails details(AppLocalizations l10n, String? type) {
    final channel = switch (type) {
      'sos' => sos(l10n),
      'chat' => chat(l10n),
      _ => places(l10n),
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
      category: type == 'sos' ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.message,
    );
  }
}
