import 'package:flutter/material.dart';

import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/member_on_map.dart';

class MemberHistoryBubble extends StatelessWidget {
  const MemberHistoryBubble({
    super.key,
    required this.entry,
    required this.now,
    required this.onTap,
    this.placeStatus,
  });

  final MemberOnMap entry;
  final DateTime now;
  final VoidCallback onTap;
  final PlaceStatus? placeStatus;

  @override
  Widget build(BuildContext context) {
    final status = TripStatus.at(entry.location, now);
    final isMoving = status.state == TripState.moving && status.speedKmh != null;
    final since = placeStatus?.since;
    final hasStay = since != null && !since.isAfter(now) && status.state != TripState.stale && !isMoving;
    final title = isMoving ? 'Onderweg' : (hasStay ? placeStatus!.name : status.label);
    final duration = hasStay ? now.difference(since) : null;
    final subtitle = isMoving
        ? '${status.speedKmh} km/u'
        : duration != null
        ? (duration.inHours > 0
              ? 'sinds ${duration.inHours} uur, ${duration.inMinutes.remainder(60)} min'
              : 'sinds ${duration.inMinutes} min')
        : 'Geschiedenis';
    final icon = isMoving
        ? Icons.directions_car
        : (hasStay ? placeIcon(placeStatus!.icon) : Icons.location_on);
    return Semantics(
      button: true,
      label: 'Geschiedenis van ${entry.member.displayName}',
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x44000000),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
          bottomRight: Radius.circular(15),
          bottomLeft: Radius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF7952AC), size: 23),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF211D27),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 12, height: 1.15, color: const Color(0xFF89818F)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
