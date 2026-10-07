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
    this.stationarySince,
    this.tailLeft = true,
  });

  final MemberOnMap entry;
  final DateTime now;
  final VoidCallback onTap;
  final PlaceStatus? placeStatus;

  /// Sinds wanneer het lid hier stilstaat, ook zonder opgeslagen plek.
  final DateTime? stationarySince;

  /// Staat de ballon rechts van de avatar? Dan wijst de staart linksonder naar
  /// de avatar; staat hij links, dan spiegelt de staart naar rechtsonder.
  final bool tailLeft;

  @override
  Widget build(BuildContext context) {
    final status = TripStatus.at(entry.location, now);
    final isMoving = status.state == TripState.moving && status.speedKmh != null;
    final placeSince = placeStatus?.since;
    final atPlace =
        placeSince != null && !placeSince.isAfter(now) && status.state != TripState.stale && !isMoving;
    // Buiten een opgeslagen plek: toon hoelang het lid hier al stilstaat.
    final stopped =
        !isMoving &&
        (status.state == TripState.stationary || status.state == TripState.unknown) &&
        stationarySince != null &&
        !stationarySince!.isAfter(now);
    final sinceTime = atPlace ? placeSince : (stopped ? stationarySince : null);
    final duration = sinceTime == null ? null : now.difference(sinceTime);
    final title = isMoving
        ? 'Onderweg'
        : atPlace
        ? placeStatus!.name
        : stopped
        ? 'Stilstaand'
        : status.label;
    final subtitle = isMoving
        ? '${status.speedKmh} km/u'
        : duration != null
        ? 'sinds ${_formatSince(duration)}'
        : _formatUpdated(entry.location?.updatedAt, now);
    final icon = isMoving
        ? Icons.directions_car
        : (atPlace ? placeIcon(placeStatus!.icon) : Icons.location_on);
    return Semantics(
      button: true,
      label: 'Geschiedenis van ${entry.member.displayName}',
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x44000000),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(15),
          bottomRight: Radius.circular(tailLeft ? 15 : 4),
          bottomLeft: Radius.circular(tailLeft ? 4 : 15),
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

String _formatSince(Duration duration) => duration.inHours > 0
    ? '${duration.inHours} uur, ${duration.inMinutes.remainder(60)} min'
    : '${duration.inMinutes} min';

/// Terugval als er geen verblijfsduur is (bv. verouderde meting): hoelang
/// geleden de laatste positie binnenkwam, i.p.v. een nietszeggende tekst.
String _formatUpdated(DateTime? updatedAt, DateTime now) {
  if (updatedAt == null) return '';
  final seconds = now.difference(updatedAt).inSeconds.clamp(0, 99999999);
  return seconds < 60 ? 'bijgewerkt $seconds s geleden' : 'bijgewerkt ${seconds ~/ 60} min geleden';
}
