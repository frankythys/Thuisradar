import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

void main() {
  // Thuis (51.170, 4.395) → Delhaize (51.180, 4.380) → terug naar huis.
  List<TrackPoint> trip() {
    final start = DateTime(2026, 10, 9, 17);
    final points = <TrackPoint>[];
    var t = start;
    void stay(double lat, double lng, int minutes) {
      for (var i = 0; i < minutes * 4; i++) {
        points.add(TrackPoint(latitude: lat, longitude: lng, recordedAt: t, speedMps: 0));
        t = t.add(const Duration(seconds: 15));
      }
    }

    void drive(double fromLat, double fromLng, double toLat, double toLng) {
      for (var i = 1; i <= 24; i++) {
        final f = i / 24;
        points.add(
          TrackPoint(
            latitude: fromLat + (toLat - fromLat) * f,
            longitude: fromLng + (toLng - fromLng) * f,
            recordedAt: t,
            speedMps: 12,
          ),
        );
        t = t.add(const Duration(seconds: 5));
      }
    }

    stay(51.170, 4.395, 10);
    drive(51.170, 4.395, 51.180, 4.380);
    stay(51.180, 4.380, 20);
    drive(51.180, 4.380, 51.170, 4.395);
    stay(51.170, 4.395, 30);
    return points;
  }

  test('nieuwste-eerst van de server geeft na sorteren twee aparte ritten heen en terug', () {
    final fromServer = trip().reversed.toList();
    final points = sortedByTime(fromServer);
    final activities = buildDayActivities(buildTimeline(points), points);
    final trips = activities.where((a) => a.kind == DrivingActivityKind.trip).toList();

    expect(trips, hasLength(2));
    // Vertrek en aankomst zonder de minuten stilstaan ervoor of erna.
    expect(trips.first.start.isAfter(DateTime(2026, 10, 9, 17, 9)), isTrue);
    expect(trips.first.end.isBefore(DateTime(2026, 10, 9, 17, 13)), isTrue);
    for (final t in trips) {
      expect(t.end.isAfter(t.start), isTrue);
      expect(t.distanceMeters, inInclusiveRange(1000, 2500));
      expect(activityTrack(t, points), isNotEmpty);
    }
  });

  test('korte straat met huisnummer i.p.v. de volledige adresregel', () {
    expect(
      shortStreet(
        thoroughfare: 'Boomsesteenweg',
        number: '174',
        street: 'Boomsesteenweg 174, 2610 Antwerpen, België',
      ),
      'Boomsesteenweg 174',
    );
    expect(shortStreet(street: 'Boomsesteenweg 174, 2610 Antwerpen, België'), 'Boomsesteenweg 174');
    expect(shortStreet(), isNull);
  });
}
