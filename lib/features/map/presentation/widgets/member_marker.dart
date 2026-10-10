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
    this.pulse,
  });

  static const width = 120.0;
  static const height = 96.0;
  static const avatarSize = 64.0;

  final MemberOnMap entry;
  final DateTime now;

  /// De opgeslagen plek wordt in de tekstballon getoond.
  final PlaceStatus? placeStatus;

  /// Geselecteerd lid: accent-selectiering en iets groter.
  final bool selected;

  /// Fase (0..1) van de lichtkring rond een geselecteerd lid; null = geen.
  final double? pulse;

  @override
  Widget build(BuildContext context) {
    final driving =
        TripStatus.at(entry.location, now).state == TripState.moving;

    final marker = _Avatar(entry: entry, selected: selected, pulse: pulse);
    // Tijdens rijden blijft het midden van de persoonscirkel op de wegpositie.
    return driving
        ? Center(child: marker)
        : Column(mainAxisSize: MainAxisSize.min, children: [marker]);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.selected, this.pulse});

  final MemberOnMap entry;
  final bool selected;
  final double? pulse;

  @override
  Widget build(BuildContext context) {
    final avatar = MemberAvatar(
      member: entry.member,
      size: MemberMarker.avatarSize,
      ring: !selected,
    );
    if (!selected) return avatar;

    // Paars is gereserveerd voor selectie en vervangt de witte rand volledig.
    final ring = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mapSelection,
        boxShadow: [
          ...context.tokens.glowSelection,
          ...context.tokens.shadowMarker,
        ],
      ),
      child: avatar,
    );
    final phase = pulse;
    if (phase == null) return ring;

    // Zachte lichtkring die uitdijt en vervaagt. Buiten het vak getekend, zodat
    // de marker zelf niet verschuift.
    final grow = 4 + 14 * phase;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -grow,
          top: -grow,
          right: -grow,
          bottom: -grow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mapSelection.withValues(alpha: 0.35 * (1 - phase)),
            ),
          ),
        ),
        ring,
      ],
    );
  }
}
