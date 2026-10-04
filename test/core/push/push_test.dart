import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/push/push_channels.dart';
import 'package:thuisradar/core/push/push_gate.dart';
import 'package:thuisradar/core/push/push_providers.dart';
import 'package:thuisradar/core/push/push_service.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';

class _Push extends Mock implements PushService {}

void main() {
  test('SOS heeft eigen alarmtoon, chat een apart meldingskanaal', () {
    final sos = PushChannels.details('sos');
    final chat = PushChannels.details('chat');
    final places = PushChannels.details('place');
    expect(sos.channelId, 'sos_alerts_v2');
    expect(sos.audioAttributesUsage, AudioAttributesUsage.alarm);
    expect(chat.channelId, isNot(places.channelId));
    expect(chat.audioAttributesUsage, AudioAttributesUsage.notification);
    for (final details in [sos, chat]) {
      final sound = details.sound! as RawResourceAndroidNotificationSound;
      expect(
        File('android/app/src/main/res/raw/${sound.sound}.wav').existsSync(),
        isTrue,
      );
      expect(details.playSound, isTrue);
    }
  });

  testWidgets('bestaande sessie registreert pas nadat kanalen klaar zijn', (
    tester,
  ) async {
    final service = _Push();
    final initialized = Completer<void>();
    when(service.init).thenAnswer((_) => initialized.future);
    when(() => service.registerFor('me')).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(service),
          currentUserIdProvider.overrideWithValue('me'),
        ],
        child: const MaterialApp(home: PushGate(child: SizedBox())),
      ),
    );
    verifyNever(() => service.registerFor('me'));
    initialized.complete();
    await tester.pump();
    verify(() => service.registerFor('me')).called(1);
  });
}
