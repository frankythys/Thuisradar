import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../domain/member_on_map.dart';
import 'location_pointer.dart';

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

  /// Straal van een geselecteerd rondje inclusief de selectierand.
  static const selectedRadius = avatarSize / 2 + 6;

  final MemberOnMap entry;
  final DateTime now;

  /// De opgeslagen plek wordt in de tekstballon getoond.
  final PlaceStatus? placeStatus;

  /// Geselecteerd lid: accent-selectiering en iets groter.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final driving = TripStatus.at(entry.location, now).driving;

    final marker = _Avatar(entry: entry, selected: selected);
    // Tijdens rijden blijft het midden van de persoonscirkel op de wegpositie.
    if (driving) return Center(child: marker);

    // Stilstaand: het rondje hangt boven de locatie, met een puntje dat naar
    // een stip op de exacte plek wijst (onderaan midden van dit vak).
    final memberColor = context.tokens.memberColor(entry.member.colorIndex);
    final avatarHeight = selected ? 2 * MemberMarker.selectedRadius : MemberMarker.avatarSize;
    // Van onder het rondje tot in de halo rond de stip.
    final tailHeight = MemberMarker.height - avatarHeight - LocationDot.haloSize / 2 + MarkerTail.overlap;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: -LocationDot.haloSize / 2,
          child: Center(child: LocationDot(color: memberColor)),
        ),
        SizedBox(
          width: avatarHeight,
          height: avatarHeight + tailHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              marker,
              // Bovenop de schaduw van het rondje; de vorm van het rondje zelf
              // blijft uit het puntje.
              Positioned(
                top: avatarHeight - MarkerTail.inset,
                child: MarkerTail(
                  color: selected ? AppColors.mapSelection : Colors.white,
                  height: tailHeight + MarkerTail.inset,
                  circleRadius: avatarHeight / 2,
                ),
              ),
            ],
          ),
        ),
      ],
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

    // Selectie: ring in de app-kleur met gloed. Een dun wit lijntje binnenin
    // houdt de ring los van een blauwgroene avatar.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mapSelection,
        boxShadow: [...context.tokens.glowSelection, ...context.tokens.shadowMarker],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: avatar,
      ),
    );
  }
}
