import 'member_location.dart';

/// Hoe een gezinslid zich verplaatst: één bron van waarheid voor de kaart,
/// de ledenlijst, het info-kaartje en het detailscherm.
enum TripState { missing, unknown, moving, stationary, stale }

class TripStatus {
  const TripStatus(this.state, this.speedKmh);

  /// Leidt de ritstatus af uit de laatste locatie en het huidige tijdstip.
  /// Snelheid telt alleen mee binnen het geldige bereik; de GPS-snelheid wordt
  /// nooit rechtstreeks getoond, enkel via deze status.
  factory TripStatus.at(MemberLocation? location, DateTime now) {
    if (location == null) return const TripStatus(TripState.missing, null);
    final speed = location.speedMps;
    final validSpeed = speed != null && speed.isFinite && speed >= 0 && speed <= 70;
    final moving = validSpeed && speed >= 1.5;
    final age = now.difference(location.updatedAt);
    if (age > Duration(seconds: moving ? 45 : 90) || age < const Duration(seconds: -10)) {
      return const TripStatus(TripState.stale, null);
    }
    if (!validSpeed) return const TripStatus(TripState.unknown, null);
    if (moving) return TripStatus(TripState.moving, (speed * 3.6).round());
    return const TripStatus(TripState.stationary, null);
  }

  final TripState state;
  final int? speedKmh;

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
  String shortDescription(
    MemberLocation? location,
    DateTime now, {
    String? place,
    String? address,
  }) {
    if (location == null) return label;
    if (state == TripState.moving) {
      if (address != null && address.isNotEmpty) return 'Rijden in de buurt van $address';
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
