import '../../../l10n/l10n.dart';
import '../domain/member_location.dart';
import '../domain/travel_mode.dart';
import '../domain/trip_status.dart';

/// Woorden bij een vervoermiddel, in de taal van de app.
extension TravelModeText on TravelMode {
  /// "Wandelen", "Fietsen" of "Rijden".
  String label(AppLocalizations l10n) => switch (this) {
    TravelMode.walk => l10n.travelWalk,
    TravelMode.bike => l10n.travelBike,
    TravelMode.car => l10n.travelCar,
  };

  /// "wandeling" of "wandelingen", volgens [count].
  String noun(AppLocalizations l10n, int count) => switch (this) {
    TravelMode.walk => l10n.travelWalkNoun(count),
    TravelMode.bike => l10n.travelBikeNoun(count),
    TravelMode.car => l10n.travelCarNoun(count),
  };

  /// "1 wandeling", "3 ritten".
  String count(AppLocalizations l10n, int count) => '$count ${noun(l10n, count)}';
}

/// "verplaatsing(en)" voor alle vervoermiddelen samen ([mode] is null).
String travelNoun(AppLocalizations l10n, TravelMode? mode, int count) =>
    mode?.noun(l10n, count) ?? l10n.travelAnyNoun(count);

/// De statusregels bij een [TripStatus], in de taal van de app.
extension TripStatusText on TripStatus {
  String label(AppLocalizations l10n) => switch (state) {
    TripState.missing => l10n.tripMissing,
    TripState.unknown => l10n.tripUnknown,
    TripState.moving => l10n.tripMoving,
    TripState.stationary => l10n.tripStationary,
    TripState.stale => l10n.tripStale,
  };

  /// Korte statusregel voor de ledenlijst: enkel wat er speelt, zonder tijd.
  /// "Thuis", "Onderweg · 42 km/u" of "Rijden in de buurt van N106".
  String shortDescription(
    AppLocalizations l10n,
    MemberLocation? location,
    DateTime now, {
    String? place,
    String? address,
  }) {
    if (location == null) return label(l10n);
    if (state == TripState.moving) {
      if (address != null && address.isNotEmpty) {
        return l10n.tripModeNear(mode?.label(l10n) ?? label(l10n), address);
      }
      if (place != null) return l10n.tripMovingNearPlace(place);
      return speedKmh == null ? l10n.tripMoving : l10n.tripMovingSpeed(speedKmh!);
    }
    if (place != null) return place;
    if (address != null && address.isNotEmpty) return address;
    return label(l10n);
  }

  /// Eén statusregel voor overal in de app: status, waar (plaats of adres),
  /// snelheid en hoe lang geleden.
  String description(
    AppLocalizations l10n,
    MemberLocation? location,
    DateTime now, {
    String? place,
    String? address,
  }) {
    if (location == null) return label(l10n);
    final seconds = now.difference(location.updatedAt).inSeconds.clamp(0, 99999999);
    return [
      if (place != null) l10n.tripLabelNearPlace(label(l10n), place) else label(l10n),
      if (place == null && address != null && address.isNotEmpty) address,
      if (speedKmh != null) l10n.speedKmh(speedKmh!),
      updatedAgo(l10n, seconds),
    ].join(' · ');
  }
}

/// "bijgewerkt 30 s geleden" of "bijgewerkt 4 min geleden".
String updatedAgo(AppLocalizations l10n, int seconds) =>
    seconds < 60 ? l10n.tripUpdatedSecondsAgo(seconds) : l10n.tripUpdatedMinutesAgo(seconds ~/ 60);
