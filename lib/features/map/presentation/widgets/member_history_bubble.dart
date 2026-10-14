import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/bubble_layout.dart';
import '../../domain/member_on_map.dart';
import 'walking_sneakers.dart';

/// Afbeeldingen in de ballon. Precies deze sleutels worden vooraf geladen
/// (`GoogleBaseMap`): een andere sleutel (bv. zonder `width`) laadt niet
/// dezelfde cache, en dan tekent Google de eerste ballon zonder afbeelding.
const bubbleCarImage = ResizeImage(AssetImage('assets/icon/Rijdende auto.png'), width: 152);

/// Blauwe mountainbike in zijaanzicht, zoals de auto: rijdt naar rechts.
const bubbleBikeImage = ResizeImage(AssetImage('assets/markers/fiets_profiel.png'), width: 152);
const bubbleHomeImage = AssetImage('assets/markers/huis.png');

/// Achtergrond van de ballon; ook het vlak onder de sneakers boven de
/// Google-kaart (`GoogleWalkerOverlay`), dat het stilstaande beeld afdekt.
const kBubbleColor = Colors.white;

/// Hoe de wandel-animatie in de ballon getekend wordt.
enum WalkerDisplay {
  /// De beelden spelen af in de ballon zelf (flutter_map: de ballon is een
  /// echte widget).
  gif,

  /// Google tekent de ballon als vaste afbeelding: in het vak staat een
  /// stilstaand beeld ([MemberHistoryBubble.walkerStill], of leeg zolang dat
  /// er niet is). De animatie speelt erboven als Flutter-widget
  /// (`GoogleWalkerOverlay`), precies op [MemberHistoryBubble.walkerSlot].
  slot,
}

class MemberHistoryBubble extends StatelessWidget {
  const MemberHistoryBubble({
    super.key,
    required this.entry,
    required this.now,
    required this.onTap,
    this.placeStatus,
    this.stationarySince,
    this.tailLeft = true,
    this.walker = WalkerDisplay.gif,
    this.walkerStill,
  });

  /// Waar de sneakers staan in een ballon van [kBubbleWidth] × [kBubbleHeight]:
  /// links binnen de opvulling, verticaal gecentreerd.
  static const walkerSlot = Rect.fromLTWH(
    _paddingX,
    (kBubbleHeight - _walkerHeight) / 2,
    _walkerWidth,
    _walkerHeight,
  );

  final MemberOnMap entry;
  final DateTime now;
  final VoidCallback onTap;
  final PlaceStatus? placeStatus;

  /// Sinds wanneer het lid hier stilstaat, ook zonder opgeslagen plek.
  final DateTime? stationarySince;

  /// Staat de ballon rechts van de avatar? Dan wijst de staart linksonder naar
  /// de avatar; staat hij links, dan spiegelt de staart naar rechtsonder.
  final bool tailLeft;

  /// Zie [WalkerDisplay].
  final WalkerDisplay walker;

  /// Stilstaand beeld van de sneakers voor [WalkerDisplay.slot].
  final ui.Image? walkerStill;

  /// Is dit de wandelballon (dus met animatie)?
  static bool isWalking(MemberOnMap entry, DateTime now) {
    final status = TripStatus.at(entry.location, now);
    return status.state == TripState.moving && status.speedKmh != null && status.walking;
  }

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
        ? status.mode!.label
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
    final icon = atPlace ? placeIcon(placeStatus!.icon) : Icons.location_on;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomRight: Radius.circular(tailLeft ? 15 : 4),
      bottomLeft: Radius.circular(tailLeft ? 4 : 15),
    );
    return Semantics(
      button: true,
      label: 'Geschiedenis van ${entry.member.displayName}',
      // Zelfde schaduw als de rondjes, plus een lichte rand die de ballon
      // laat loskomen van een lichte kaart.
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: context.tokens.shadowBubble),
        child: Material(
          color: kBubbleColor,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _paddingX, vertical: 5),
              child: Row(
                children: [
                  if (isMoving && status.walking)
                    _walkerImage()
                  else if (isMoving)
                    Image(
                      image: status.cycling ? bubbleBikeImage : bubbleCarImage,
                      width: 38,
                      height: 32,
                      fit: BoxFit.contain,
                    )
                  else if (atPlace && placeStatus!.icon == 'home')
                    const Image(image: bubbleHomeImage, width: 32, height: 32, fit: BoxFit.contain)
                  else
                    Icon(icon, color: AppColors.primary, size: 23),
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
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 12, height: 1.15, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// De wandelende sneakers in hun vak ([walkerSlot]).
  Widget _walkerImage() => switch (walker) {
    WalkerDisplay.gif => const WalkingSneakers(width: _walkerWidth, height: _walkerHeight),
    WalkerDisplay.slot => SizedBox(
      width: _walkerWidth,
      height: _walkerHeight,
      child: walkerStill == null ? null : RawImage(image: walkerStill, fit: BoxFit.contain),
    ),
  };
}

/// Vak voor de sneakers: breder dan hoog, zoals het paar schoenen.
const _walkerWidth = 52.0;
const _walkerHeight = 32.0;
const _paddingX = 8.0;

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
