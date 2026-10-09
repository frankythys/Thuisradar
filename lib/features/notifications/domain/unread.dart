import '../../location/domain/member_location.dart';
import 'family_event.dart';

/// Vanaf dit percentage (en niet aan het laden) toont de app een batterijwaarschuwing.
const lowBatteryThreshold = 20;

bool isLowBattery(MemberLocation location) =>
    (location.battery ?? 100) <= lowBatteryThreshold && location.isCharging != true;

/// Gezinsleden die nu een batterijwaarschuwing hebben.
Set<String> lowBatteryUserIds(Iterable<MemberLocation> locations) => {
  for (final l in locations)
    if (isLowBattery(l)) l.userId,
};

/// Aantal ongelezen meldingen voor het belletje.
///
/// Telt gebeurtenissen van ánderen na [lastSeen], plus batterijwaarschuwingen
/// die nog niet gezien zijn. Een waarschuwing is gezien zodra de meldingen
/// geopend werden terwijl ze al gold ([seenLowBattery]).
int unreadNotifications({
  required Iterable<FamilyEvent> events,
  required String? userId,
  required DateTime? lastSeen,
  required Set<String> lowBattery,
  required Set<String> seenLowBattery,
}) {
  final newEvents = events.where(
    (e) => e.actorUserId != userId && (lastSeen == null || e.createdAt.isAfter(lastSeen)),
  );
  return newEvents.length + lowBattery.difference(seenLowBattery).length;
}
