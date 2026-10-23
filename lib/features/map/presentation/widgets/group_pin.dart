import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../driving/presentation/travel_mode_filter.dart' show travelModeIcon;
import '../../../location/domain/travel_mode.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/member_on_map.dart';
import 'group_pin_backdrop.dart';
import '../../../../l10n/l10n.dart';

/// Groepspin voor leden die op het scherm dicht bij elkaar staan: overlappende
/// avatars als piramide (1 bovenaan, dan 2, dan 3; vanaf 7 leden is de laatste
/// "+N"), een statusballon met de meest recente status, en een puntje naar de
/// locatie.
class GroupPin extends StatelessWidget {
  const GroupPin({
    super.key,
    required this.members,
    required this.now,
    this.placeByUser = const {},
    this.myUserId,
    this.selectedUserId,
    this.onMemberTap,
  });

  static const width = 260.0;

  /// Hoogte bij één rij cirkels; zie [heightFor].
  static const height = 160.0;

  static const _avatar = 72.0;
  static const _step = 58.0;

  /// Verticale afstand tussen de rijen: schuine buren liggen even ver uit
  /// elkaar als buren naast elkaar (58 × sin 60°).
  static const _rowStep = 50.0;
  static const _maxSlots = 6;

  /// Lengte van het puntje onder de cirkels; de punt zelf is de plek.
  static const _tip = 14.0;

  /// Breedte van de gezamenlijke witte rand rond de groep.
  static const _inset = 1.0;

  /// Leden in deze groep; de eerste is "ik" (indien aanwezig), die bovenop ligt.
  final List<MemberOnMap> members;
  final DateTime now;
  final Map<String, PlaceStatus> placeByUser;
  final String? myUserId;
  final String? selectedUserId;

  /// Tik op één avatar in de groep: toon de info van dat lid.
  final ValueChanged<MemberOnMap>? onMemberTap;

  /// Aantal cirkels per rij, van boven naar onder. De onderste rij is het
  /// breedst, zodat het een piramide blijft.
  static List<int> _rows(int count) => switch (count.clamp(1, _maxSlots)) {
    1 => const [1],
    2 => const [2],
    3 => const [1, 2],
    4 => const [1, 3],
    5 => const [2, 3],
    _ => const [1, 2, 3],
  };

  /// Linkerbovenhoek van elke cirkel; elke rij staat gecentreerd.
  static List<Offset> _origins(int count) {
    final rows = _rows(count);
    final widest = rows.last;
    return [
      for (final (row, size) in rows.indexed)
        for (var i = 0; i < size; i++) Offset(((widest - size) / 2 + i) * _step, row * _rowStep),
    ];
  }

  /// Breedte van de piramide cirkels voor [count] leden.
  static double clusterWidth(int count) => (_rows(count).last - 1) * _step + _avatar;

  /// Hoogte van de piramide cirkels met het puntje eronder.
  static double clusterHeight(int count) => (_rows(count).length - 1) * _rowStep + _avatar + _tip;

  /// Waar de cirkels (met het puntje) op het scherm staan voor een pin op
  /// [point], verschoven met [shift]: het puntje wijst naar het punt.
  static Rect circlesAt(Offset point, int count, {Offset shift = Offset.zero}) => Rect.fromLTWH(
    point.dx + shift.dx - clusterWidth(count) / 2,
    point.dy + shift.dy - clusterHeight(count),
    clusterWidth(count),
    clusterHeight(count),
  );

  /// Hoogte van de hele pin: elke extra rij cirkels maakt hem hoger.
  static double heightFor(int count) => height + (_rows(count).length - 1) * _rowStep;

  /// Zichtbare leden: allemaal tot 6, daarna 5 en een "+N".
  List<MemberOnMap> get _shown =>
      members.length <= _maxSlots ? members : members.take(_maxSlots - 1).toList();

  /// Alles wat het getekende beeld bepaalt, als vergelijkbare sleutel: Google
  /// tekent de groepspin enkel opnieuw als die verandert.
  String imageKey(AppLocalizations l10n) {
    final info = _info(l10n);
    return [
      for (final member in _shown)
        '${member.member.userId}:${member.member.initial}:${member.member.colorIndex}:'
            '${member.member.userId == selectedUserId}',
      members.length,
      info.icon.codePoint,
      info.title,
      if (info.at != null) formatRelative(l10n, info.at!, now: now),
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final extra = members.length - shown.length;
    final origins = _origins(members.length);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Bubble(info: _info(context.l10n), now: now),
        const SizedBox(height: 4),
        SizedBox(
          width: clusterWidth(members.length),
          height: origins.last.dy + _avatar + _tip,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Eén witte vorm achter alle cirkels: de randen vloeien in elkaar
              // en onderaan wijst een puntje naar de plek.
              GroupPinBackdrop(
                origins: origins,
                diameter: _avatar,
                step: _step,
                tip: _tip,
                color: Colors.white,
                shadows: context.tokens.shadowMarker,
              ),
              if (extra > 0)
                Positioned(
                  left: origins.last.dx + _inset,
                  top: origins.last.dy + _inset,
                  child: _plus(extra),
                ),
              // Achterste eerst tekenen; "ik" (index 0) komt zo bovenop.
              for (final (index, member) in shown.indexed.toList().reversed)
                Positioned(
                  left: origins[index].dx + _inset,
                  top: origins[index].dy + _inset,
                  child: _avatarFor(context, member),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarFor(BuildContext context, MemberOnMap member) {
    final isSelected = member.member.userId == selectedUserId;
    const inner = _avatar - 2 * _inset;
    // Binnen de witte vorm: een dun wit lijntje scheidt overlappende cirkels;
    // de gekozen persoon krijgt een volle rand in de app-kleur met gloed.
    final avatar = MemberAvatar(member: member.member, size: inner - (isSelected ? 10 : 4));
    final child = Container(
      width: inner,
      height: inner,
      padding: EdgeInsets.all(isSelected ? 5 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.mapSelection : Colors.white,
        boxShadow: isSelected ? context.tokens.glowSelection : null,
      ),
      child: avatar,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMemberTap == null ? null : () => onMemberTap!(member),
      child: child,
    );
  }

  Widget _plus(int extra) {
    return Container(
      width: _avatar - 2 * _inset,
      height: _avatar - 2 * _inset,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '+$extra',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }

  /// Meest recente status binnen de groep: icoon, titel en tijd.
  ({IconData icon, String title, DateTime? at}) _info(AppLocalizations l10n) {
    MemberOnMap? latest;
    for (final member in members) {
      final location = member.location;
      if (location == null) continue;
      if (latest == null || location.updatedAt.isAfter(latest.location!.updatedAt)) {
        latest = member;
      }
    }
    if (latest == null) {
      return (icon: Icons.group, title: l10n.mapGroupMembers(members.length), at: null);
    }

    final name = latest.member.displayName;
    final place = placeByUser[latest.member.userId];
    if (place != null) {
      return (
        icon: placeIcon(place.icon),
        title: l10n.mapArrived(name),
        at: place.since ?? latest.location!.updatedAt,
      );
    }
    final trip = TripStatus.at(latest.location, now);
    if (trip.speedKmh != null) {
      return (
        icon: travelModeIcon(trip.mode ?? TravelMode.car),
        title: l10n.mapOnTheWay(name),
        at: latest.location!.updatedAt,
      );
    }
    return (icon: Icons.location_on_outlined, title: name, at: latest.location!.updatedAt);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.info, required this.now});

  final ({IconData icon, String title, DateTime? at}) info;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: GroupPin.width),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: context.tokens.shadowBubble,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.icon == Icons.home_rounded)
            Image.asset('assets/markers/huis.png', width: 28, height: 28, fit: BoxFit.contain)
          else
            Icon(info.icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: AppColors.ink, fontSize: text.labelSmall?.fontSize),
                ),
                if (info.at != null)
                  Text(
                    formatRelative(context.l10n, info.at!, now: now),
                    style: text.labelSmall?.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
