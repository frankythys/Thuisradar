import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/battery_badge.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../location/application/address_providers.dart';
import '../../../location/domain/place_address.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../domain/member_on_map.dart';

/// Eén rij in de ledenkaart: afgeronde avatar met batterijpil, de naam, een
/// korte statusregel en "Sinds HH:mm". Leden zonder signaal krijgen een rode
/// staat met een doorgestreept toestelicoon.
class MemberTile extends ConsumerWidget {
  const MemberTile({
    super.key,
    required this.entry,
    required this.isMe,
    required this.now,
    this.placeStatus,
    this.onTap,
  });

  final MemberOnMap entry;
  final bool isMe;
  final DateTime now;

  /// Waar dit lid nu is (plaats), indien binnen een zone.
  final PlaceStatus? placeStatus;

  /// Tik op de rij: beweeg de kaart naar dit lid.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final location = entry.location;
    final status = TripStatus.at(location, now);
    final offline = _isOffline(status);
    final address = location == null
        ? null
        : ref
              .watch(
                placeAddressProvider(
                  snapToAddressGrid(location.latitude, location.longitude),
                ),
              )
              .value;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(entry: entry),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe
                        ? '${entry.member.displayName} (jij)'
                        : entry.member.displayName,
                    style: text.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceXs),
                  Text(
                    _status(status, address, offline),
                    style: text.bodySmall?.copyWith(
                      color: offline ? AppColors.alert : AppColors.muted,
                    ),
                  ),
                  if (location != null && !offline)
                    Text(
                      'Sinds ${formatSince(location.updatedAt, now: now)}',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (offline)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Tooltip(
                  message: 'Geen netwerk of telefoon uit',
                  child: Icon(
                    Icons.phonelink_off,
                    color: AppColors.alert,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Geen signaal: al even niets ontvangen of nog nooit gedeeld.
  bool _isOffline(TripStatus status) =>
      status.state == TripState.stale || status.state == TripState.missing;

  String _status(TripStatus status, PlaceAddress? address, bool offline) {
    if (status.state == TripState.missing) return 'Nog geen locatie gedeeld';
    if (offline) return 'Geen netwerk of telefoon uit';

    return status.shortDescription(
      entry.location,
      now,
      place: placeStatus?.name,
      address: address?.label,
    );
  }
}

/// Avatar met de batterijstand als pilletje over de onderrand.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry});

  final MemberOnMap entry;

  @override
  Widget build(BuildContext context) {
    final location = entry.location;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MemberAvatar(
            member: entry.member,
            size: 64,
            shape: MemberAvatarShape.rounded,
          ),
          if (location?.battery != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: -10,
              child: Center(
                child: BatteryBadge(
                  level: location!.battery,
                  isCharging: location.isCharging,
                  compact: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
