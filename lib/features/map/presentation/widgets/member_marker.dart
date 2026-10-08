import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../domain/member_on_map.dart';

class MemberMarker extends StatelessWidget {
  const MemberMarker({
    super.key,
    required this.entry,
    required this.now,
    this.placeStatus,
    this.selected = false,
  });

  static const width = 120.0;
  static const height = 96.0;
  static const avatarSize = 64.0;

  final MemberOnMap entry;
  final DateTime now;

  /// De opgeslagen plek waar dit lid nu is (indien binnen een zone). Thuis
  /// krijgt een huis-icoon op de kaart.
  final PlaceStatus? placeStatus;

  /// Geselecteerd lid: accent-selectiering en iets groter.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final atHome = placeStatus?.icon == 'home';
    final driving = TripStatus.at(entry.location, now).state == TripState.moving;

    final Widget marker;
    if (atHome) {
      marker = _IconMarker(entry: entry, selected: selected, asset: 'assets/markers/huis.png', width: 64);
    } else if (driving) {
      marker = _IconMarker(entry: entry, selected: selected, asset: 'assets/markers/auto.png', width: 74);
    } else {
      marker = _Avatar(entry: entry, selected: selected);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [marker]);
  }
}

/// Een beeld-marker (auto tijdens het rijden of huis als iemand thuis is) met
/// een klein avatar-badge zodat je ziet om wie het gaat.
class _IconMarker extends StatelessWidget {
  const _IconMarker({
    required this.entry,
    required this.selected,
    required this.asset,
    required this.width,
  });

  final MemberOnMap entry;
  final bool selected;
  final String asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width + 10,
      height: width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.mapSelection,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: context.tokens.shadowLevel2,
                ),
              ),
            ),
          Image.asset(asset, width: width),
          Positioned(top: 0, left: 0, child: MemberAvatar(member: entry.member, size: 28, ring: true)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.selected});

  final MemberOnMap entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final avatar = MemberAvatar(member: entry.member, size: MemberMarker.avatarSize, ring: !selected);
    if (!selected) return avatar;

    // Paars is gereserveerd voor selectie en vervangt de witte rand volledig.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mapSelection,
        boxShadow: context.tokens.shadowLevel2,
      ),
      child: avatar,
    );
  }
}
