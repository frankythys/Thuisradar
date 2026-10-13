import 'member_location.dart';
import 'motion_filter.dart' show kMovingSpeedMps;
import 'travel_mode.dart';

/// Hoe een gezinslid zich verplaatst: één bron van waarheid voor de kaart,
/// de ledenlijst, het info-kaartje en het detailscherm.
enum TripState { missing, unknown, moving, stationary, stale }

/// Vanaf deze snelheid (km/u) toont één losse meting zonder geschiedenis een
/// fiets; joggen (±10 km/u) valt er net onder.
const kBikeDisplayKmh = 12;

class TripStatus {
  const TripStatus(this.state, this.speedKmh, {this.mode});

  /// Leidt de ritstatus af uit de laatste locatie en het huidige tijdstip.
  /// Met een [MemberLocation.tripHint] (de stroom van het gezin) beslist het
  /// geheugen over meerdere metingen; zonder telt enkel deze meting. De
  /// GPS-snelheid wordt nooit rechtstreeks getoond, enkel via deze status.
  factory TripStatus.at(MemberLocation? location, DateTime now) {
    if (location == null) return const TripStatus(TripState.missing, null);
    final speed = location.speedMps;
    final validSpeed = speed != null && speed.isFinite && speed >= 0 && speed <= 70;
    final hint = location.tripHint;
    final moving = hint?.moving ?? (validSpeed && speed >= kMovingSpeedMps);
    final age = now.difference(location.updatedAt);
    if (age > Duration(seconds: moving ? 45 : 90) || age < const Duration(seconds: -10)) {
      return const TripStatus(TripState.stale, null);
    }
    if (hint == null && !validSpeed) return const TripStatus(TripState.unknown, null);
    if (!moving) return const TripStatus(TripState.stationary, null);
    final kmh = hint?.speedKmh ?? (validSpeed ? (speed * 3.6).round() : null);
    if (kmh == null) return const TripStatus(TripState.unknown, null);
    return TripStatus(TripState.moving, kmh, mode: hint?.mode ?? travelModeForSpeed(kmh));
  }

  final TripState state;
  final int? speedKmh;

  /// Vervoermiddel; enkel onderweg. Een schatting die enkel het icoon en de
  /// woorden kiest.
  final TravelMode? mode;

  /// Te voet onderweg.
  bool get walking => state == TripState.moving && mode == TravelMode.walk;

  /// Met de fiets onderweg.
  bool get cycling => state == TripState.moving && mode == TravelMode.bike;

  /// Met de auto onderweg: de kaart toont dan een rijdende marker
  /// (gecentreerd op de weg, zonder puntje).
  bool get driving => state == TripState.moving && mode == TravelMode.car;

  bool get canFollow => state != TripState.missing && state != TripState.stale;

  String get label => switch (state) {
    TripState.missing => 'Nog geen locatie gedeeld',
    TripState.unknown => 'Beweging onbekend',
    TripState.moving => 'Onderweg',
    TripState.stationary => 'Stilstaand',
    TripState.stale => 'Locatie niet actueel',
  };

  /// Korte statusregel voor de ledenlijst: enkel wat er speelt, zonder tijd.
  /// "Thuis", "Onderweg · 42 km/u" of "Rijden in de buurt van N106".
  String shortDescription(MemberLocation? location, DateTime now, {String? place, String? address}) {
    if (location == null) return label;
    if (state == TripState.moving) {
      if (address != null && address.isNotEmpty) {
        return '${mode?.label ?? label} in de buurt van $address';
      }
      if (place != null) return 'Onderweg · nabij $place';
      return speedKmh == null ? 'Onderweg' : 'Onderweg · $speedKmh km/u';
    }
    if (place != null) return place;
    if (address != null && address.isNotEmpty) return address;
    return label;
  }

  /// Eén statusregel voor overal in de app: status, waar (plaats of adres),
  /// snelheid en hoe lang geleden.
  String description(MemberLocation? location, DateTime now, {String? place, String? address}) {
    if (location == null) return label;
    final seconds = now.difference(location.updatedAt).inSeconds.clamp(0, 99999999);
    final age = seconds < 60 ? '$seconds s geleden' : '${seconds ~/ 60} min geleden';
    final where = switch ((place, address)) {
      (final p?, _) => ' nabij $p',
      (_, final a?) when a.isNotEmpty => ' · $a',
      _ => '',
    };
    final velocity = speedKmh == null ? '' : ' · $speedKmh km/u';
    return '$label$where$velocity · bijgewerkt $age';
  }
}

/// Vervoermiddel bij één losse snelheid (km/u), zonder geschiedenis.
TravelMode travelModeForSpeed(int kmh) => kmh >= kCarSpeedKmh
    ? TravelMode.car
    : kmh >= kBikeDisplayKmh
    ? TravelMode.bike
    : TravelMode.walk;
