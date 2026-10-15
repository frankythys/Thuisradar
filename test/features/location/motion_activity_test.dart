import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/motion_activity.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);
  ActivityReading reading(MotionActivity? activity, {int confidence = 90, int secondsAgo = 3}) =>
      ActivityReading(activity, confidence, now.subtract(Duration(seconds: secondsAgo)));

  group('currentActivity', () {
    test('een verse, zekere herkenning gaat mee', () {
      expect(currentActivity(reading(MotionActivity.vehicle), now), MotionActivity.vehicle);
      expect(currentActivity(reading(MotionActivity.bicycle, confidence: 70), now), MotionActivity.bicycle);
    });

    test('te onzeker telt niet', () {
      expect(currentActivity(reading(MotionActivity.vehicle, confidence: 69), now), isNull);
    });

    test('ouder dan 30 s telt niet: GPS en stappen beslissen dan alleen', () {
      expect(currentActivity(reading(MotionActivity.foot, secondsAgo: 30), now), MotionActivity.foot);
      expect(currentActivity(reading(MotionActivity.foot, secondsAgo: 31), now), isNull);
    });

    test('een tijdstip ver in de toekomst is een verkeerde klok', () {
      expect(currentActivity(reading(MotionActivity.still, secondsAgo: -5), now), MotionActivity.still);
      expect(currentActivity(reading(MotionActivity.still, secondsAgo: -11), now), isNull);
    });

    test('geen of onbekende herkenning: null', () {
      expect(currentActivity(null, now), isNull);
      expect(currentActivity(reading(null), now), isNull);
    });
  });

  test('kolomwaarden heen en terug; onbekend wordt null', () {
    for (final activity in MotionActivity.values) {
      expect(MotionActivity.fromDb(activity.dbValue), activity);
    }
    expect(MotionActivity.fromDb('train'), isNull);
    expect(MotionActivity.fromDb(null), isNull);
  });

  group('MemberLocation', () {
    MemberLocation location({MotionActivity? activity}) => MemberLocation(
      userId: 'u1',
      familyId: 'f1',
      latitude: 51,
      longitude: 4,
      activity: activity,
      updatedAt: DateTime.utc(2026, 10, 15, 12),
    );

    test('de activiteit gaat mee naar de database en terug', () {
      final json = location(activity: MotionActivity.bicycle).toJson();
      expect(json['activity'], 'bicycle');
      expect(MemberLocation.fromJson(json).activity, MotionActivity.bicycle);
    });

    test('zonder activiteit geen kolom: uploaden werkt ook zonder migratie 020', () {
      expect(location().toJson().containsKey('activity'), isFalse);
    });

    test('copyWith behoudt de activiteit', () {
      expect(
        location(activity: MotionActivity.vehicle).copyWith(latitude: 50).activity,
        MotionActivity.vehicle,
      );
    });
  });
}
