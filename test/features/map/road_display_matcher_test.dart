import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/map/application/road_display_matcher.dart';
import 'package:thuisradar/features/map/data/road_network_source.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/domain/road_matching.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';

import 'road_matching_test.dart' as sample;

class FakeRoads extends RoadNetworkSource {
  FakeRoads() : super(MockClient((_) async => http.Response('', 500)));
  final network = RoadNetwork([sample.road(1, 0)], {});
  Completer<RoadNetwork?>? pending;
  @override
  Future<RoadNetwork?> forFix(MemberLocation fix, DateTime now) async =>
      pending == null ? network : await pending!.future;
}

void main() {
  MemberOnMap member(int second, {double speed = 10}) => MemberOnMap(
    member: const FamilyMember(
      userId: 'u',
      displayName: 'Franky',
      isOwner: true,
      colorIndex: 0,
    ),
    location: sample.fix(second * 10, 12, second, speed: speed),
  );
  test(
    'alleen weergave verandert; stop en nieuwe GPS-fix blijven origineel',
    () async {
      final source = FakeRoads();
      addTearDown(source.client.close);
      final matcher = RoadDisplayMatcher(source);
      for (final second in [0, 5, 10]) {
        final raw = member(second);
        await matcher.update([raw], raw.location!.updatedAt);
      }
      final raw = member(10);
      final shown = matcher
          .display([raw], raw.location!.updatedAt)
          .single
          .location!;
      expect(shown.latitude, closeTo(0, 1e-9));
      expect(raw.location!.latitude, isNot(0));
      expect(shown.updatedAt, raw.location!.updatedAt);
      final newer = member(15);
      expect(
        matcher.display([newer], newer.location!.updatedAt).single,
        same(newer),
      );
      final stopped = member(15, speed: 0);
      await matcher.update([stopped], stopped.location!.updatedAt);
      expect(
        matcher.display([stopped], stopped.location!.updatedAt).single,
        same(stopped),
      );
    },
  );
  test('oud netwerkantwoord mag een stop niet terugzetten op de weg', () async {
    final source = FakeRoads();
    addTearDown(source.client.close);
    final matcher = RoadDisplayMatcher(source);
    for (final second in [0, 5]) {
      final raw = member(second);
      await matcher.update([raw], raw.location!.updatedAt);
    }
    source.pending = Completer<RoadNetwork?>();
    final raw = member(10);
    final request = matcher.update([raw], raw.location!.updatedAt);
    final stopped = member(15, speed: 0);
    await matcher.update([stopped], stopped.location!.updatedAt);
    source.pending!.complete(source.network);
    await request;
    expect(
      matcher.display([stopped], stopped.location!.updatedAt).single,
      same(stopped),
    );
  });
}
