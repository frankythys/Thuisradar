import 'member_location.dart';
import 'trip_status.dart';

/// Onthoudt een herkende rit tijdens afremmen en korte verkeerslichtstops.
/// Een langere stop, een onderbroken stroom of gezette stappen beëindigt die
/// voorkeur. Dit is enkel weergave; GPS en ritgeschiedenis blijven origineel.
class DrivingModeMemory {
  final _members = <String, _Mode>{};
  static const _parkedAfter = Duration(seconds: 90);

  List<MemberLocation> update(List<MemberLocation> locations, DateTime now) {
    final present = locations.map((location) => location.userId).toSet();
    _members.removeWhere((id, _) => !present.contains(id));
    return [for (final location in locations) _update(location, now)];
  }

  MemberLocation _update(MemberLocation location, DateTime now) {
    final mode = _members.putIfAbsent(location.userId, _Mode.new);
    final previous = mode.updatedAt;
    if (previous != null && !location.updatedAt.isAfter(previous)) {
      return location.copyWith(drivingHint: mode.driving);
    }
    if (previous != null && location.updatedAt.difference(previous) > const Duration(seconds: 45)) {
      mode.reset();
    }
    mode.updatedAt = location.updatedAt;
    final status = TripStatus.at(location, now);
    if (status.state == TripState.stale) {
      mode.reset();
    } else if (status.driving) {
      mode.driving = true;
      mode.stoppedAt = null;
      mode.steps = location.steps;
    } else if (status.state == TripState.stationary) {
      mode.stoppedAt ??= location.updatedAt;
      if (location.updatedAt.difference(mode.stoppedAt!) >= _parkedAfter) mode.driving = false;
    } else if (status.state == TripState.moving) {
      if (mode.stoppedAt != null && location.updatedAt.difference(mode.stoppedAt!) >= _parkedAfter) {
        mode.driving = false;
      }
      final steps = location.steps;
      if (steps != null && mode.steps != null && steps - mode.steps! >= 12) mode.driving = false;
      if (steps != null && (mode.steps == null || steps < mode.steps!)) mode.steps = steps;
      mode.stoppedAt = null;
    }
    return location.copyWith(drivingHint: mode.driving);
  }
}

class _Mode {
  DateTime? updatedAt;
  DateTime? stoppedAt;
  int? steps;
  bool driving = false;

  void reset() {
    driving = false;
    stoppedAt = null;
    steps = null;
  }
}
