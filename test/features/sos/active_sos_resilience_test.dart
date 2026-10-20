import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/utils/resync_signal.dart';
import 'package:thuisradar/features/sos/application/sos_providers.dart';
import 'package:thuisradar/features/sos/data/sos_repository.dart';
import 'package:thuisradar/features/sos/domain/sos_alert.dart';

class _Repo extends Mock implements SosRepository {}

SosAlert _alert(String id) => SosAlert(
  id: id,
  familyId: 'fam',
  userId: 'liam',
  latitude: 51,
  longitude: 4,
  active: true,
  createdAt: DateTime(2026, 10, 20),
);

void main() {
  test('een weggevallen SOS-kanaal opent opnieuw en een nieuw alarm komt binnen', () async {
    final repo = _Repo();
    final channels = <StreamController<List<SosAlert>>>[];
    when(() => repo.watchActive('fam')).thenAnswer((_) {
      final channel = StreamController<List<SosAlert>>();
      channels.add(channel);
      return channel.stream;
    });
    final container = ProviderContainer(overrides: [sosRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    final seen = <List<SosAlert>>[];
    container.listen(activeSosProvider('fam'), (_, next) {
      if (next.hasValue) seen.add(next.requireValue);
    });

    channels.single.add(const []);
    await pumpEventQueue();
    // Het realtime-kanaal valt weg (zoals op de achtergrond).
    await channels.single.close();
    // Terug op de voorgrond: meteen opnieuw openen.
    container.read(resyncSignalProvider).notify();
    await pumpEventQueue();
    expect(channels, hasLength(2));

    channels.last.add([_alert('a1')]);
    await pumpEventQueue();
    expect(seen.last.single.id, 'a1');
  });
}
