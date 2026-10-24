import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../../places/presentation/place_images.dart';
import '../../domain/bubble_layout.dart';
import '../../domain/member_on_map.dart';
import 'walking_sneakers.dart';
import '../../../../l10n/l10n.dart';
import '../../../location/presentation/trip_text.dart';

/// Afbeeldingen in de ballon. Precies deze sleutels worden vooraf geladen
/// (`GoogleBaseMap`): een andere sleutel (bv. zonder `width`) laadt niet
/// dezelfde cache, en dan tekent Google de eerste ballon zonder afbeelding.
const bubbleCarImage = ResizeImage(
  AssetImage('assets/icon/Rijdende auto.png'),
  width: 152,
);

/// Blauwe mountainbike in zijaanzicht, zoals de auto: rijdt naar rechts.
const bubbleBikeImage = ResizeImage(
  AssetImage('assets/markers/fiets_profiel.png'),
  width: 152,
);
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

  /// Waar de sneakers staan in een ballon van [kBubbleWidth] × [kBubbleHeight]
  /// met de staart links: links binnen de opvulling, verticaal gecentreerd.
  /// Met de staart rechts zie [walkerSlotFor].
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

  /// Het vak van de sneakers in het vak van [kBubbleWidth] breed. De ballon is
  /// zo breed als zijn inhoud en staat tegen de kant van de avatar: met de
  /// staart rechts schuift het vak dus mee naar rechts.
  static Rect walkerSlotFor(
    BuildContext context,
    MemberOnMap entry,
    DateTime now, {
    required bool tailLeft,
  }) {
    if (tailLeft) return walkerSlot;
    final speed = TripStatus.at(entry.location, now).speedKmh;
    if (speed == null) return walkerSlot;
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.speedKmh(speed),
        style: _titleStyle(context),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = math.min(
      kBubbleWidth,
      2 * _paddingX + _walkerWidth + _iconGap + painter.width,
    );
    painter.dispose();
    return walkerSlot.shift(Offset(kBubbleWidth - width, 0));
  }

  /// Is dit de wandelballon (dus met animatie)?
  static bool isWalking(MemberOnMap entry, DateTime now) {
    final status = TripStatus.at(entry.location, now);
    return status.state == TripState.moving &&
        status.speedKmh != null &&
        status.walking;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = TripStatus.at(entry.location, now);
    final isMoving =
        status.state == TripState.moving && status.speedKmh != null;
    final placeSince = placeStatus?.since;
    final atPlace =
        placeSince != null &&
        !placeSince.isAfter(now) &&
        status.state != TripState.stale &&
        !isMoving;
    // Buiten een opgeslagen plek: toon hoelang het lid hier al stilstaat.
    final stopped =
        !isMoving &&
        (status.state == TripState.stationary ||
            status.state == TripState.unknown) &&
        stationarySince != null &&
        !stationarySince!.isAfter(now);
    final sinceTime = atPlace ? placeSince : (stopped ? stationarySince : null);
    final duration = sinceTime == null ? null : now.difference(sinceTime);
    // Onderweg zegt het icoon (auto, fiets, wandelaar) al hoe; enkel de snelheid.
    final title = isMoving
        ? l10n.speedKmh(status.speedKmh!)
        : atPlace
        ? placeStatus!.name
        : stopped
        ? l10n.tripStationary
        : status.label(l10n);
    final String? subtitle = isMoving
        ? null
        : duration != null
        ? l10n.mapSince(_formatStay(l10n, duration))
        : _formatUpdated(l10n, entry.location?.updatedAt, now);
    final icon = atPlace ? placeIcon(placeStatus!.icon) : Icons.location_on;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomRight: Radius.circular(tailLeft ? 15 : 4),
      bottomLeft: Radius.circular(tailLeft ? 4 : 15),
    );
    // Zo breed als de inhoud plus vaste opvulling, tegen de kant van de
    // avatar (waar de staart wijst); de rest van het vak blijft leeg.
    return Row(
      mainAxisAlignment: tailLeft
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: Semantics(
            button: true,
            label: l10n.mapHistoryOf(entry.member.displayName),
            // Zelfde schaduw als de rondjes, plus een lichte rand die de ballon
            // laat loskomen van een lichte kaart.
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: context.tokens.shadowBubble,
              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: _paddingX,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMoving && status.walking)
                          Semantics(
                            label: status.mode!.label(l10n),
                            child: _walkerImage(),
                          )
                        else if (isMoving)
                          Image(
                            image: status.cycling
                                ? bubbleBikeImage
                                : bubbleCarImage,
                            semanticLabel: status.mode!.label(l10n),
                            width: 38,
                            height: 32,
                            fit: BoxFit.contain,
                          )
                        else if ((atPlace
                                ? placeBubbleImage(placeStatus!.icon)
                                : null)
                            case final photo?)
                          Image(
                            image: photo,
                            width: 38,
                            height: 32,
                            fit: BoxFit.contain,
                          )
                        else
                          Icon(icon, color: AppColors.primary, size: 23),
                        const SizedBox(width: _iconGap),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _titleStyle(context),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 12,
                                        height: 1.15,
                                        color: AppColors.muted,
                                      ),
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
          ),
        ),
      ],
    );
  }

  /// De wandelende sneakers in hun vak ([walkerSlot]).
  Widget _walkerImage() => switch (walker) {
    WalkerDisplay.gif => const WalkingSneakers(
      width: _walkerWidth,
      height: _walkerHeight,
    ),
    WalkerDisplay.slot => SizedBox(
      width: _walkerWidth,
      height: _walkerHeight,
      child: walkerStill == null
          ? null
          : RawImage(image: walkerStill, fit: BoxFit.contain),
    ),
  };
}

/// Vak voor de sneakers: breder dan hoog, zoals het paar schoenen.
const _walkerWidth = 52.0;
const _walkerHeight = 32.0;
const _paddingX = 8.0;
const _iconGap = 5.0;

TextStyle? _titleStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodyMedium
    ?.copyWith(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

String _formatStay(AppLocalizations l10n, Duration duration) =>
    duration.inHours > 0
    ? l10n.mapStayHoursMinutes(
        duration.inHours,
        duration.inMinutes.remainder(60),
      )
    : l10n.durationMinutes(duration.inMinutes);

/// Terugval als er geen verblijfsduur is (bv. verouderde meting): hoelang
/// geleden de laatste positie binnenkwam, i.p.v. een nietszeggende tekst.
String _formatUpdated(
  AppLocalizations l10n,
  DateTime? updatedAt,
  DateTime now,
) {
  if (updatedAt == null) return '';
  return updatedAgo(
    l10n,
    now.difference(updatedAt).inSeconds.clamp(0, 99999999),
  );
}
