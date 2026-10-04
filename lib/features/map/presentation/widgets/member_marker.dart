import 'package:flutter/material.dart';

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
    this.selected = false,
    this.placeStatus,
  });

  static const width = 120.0;
  static const height = 92.0;

  final MemberOnMap entry;
  final DateTime now;

  /// Geselecteerd lid: accent-selectiering en iets groter.
  final bool selected;

  /// Waar dit lid nu is (plaats), indien binnen een zone.
  final PlaceStatus? placeStatus;

  @override
  Widget build(BuildContext context) {
    final speed = TripStatus.at(entry.location, now).speedKmh;
    final label = placeStatus != null
        ? placeStatus!.name
        : (speed != null ? '$speed km/u' : entry.member.displayName);

    return Transform.scale(
      scale: selected ? 1.15 : 1.0,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(entry: entry, selected: selected),
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x26121C1C), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
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
    final avatar = MemberAvatar(member: entry.member, ring: true);
    if (!selected) return avatar;

    // Accent-selectiering met witte binnenrand (niet de hele cirkel inkleuren).
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: avatar,
      ),
    );
  }
}
