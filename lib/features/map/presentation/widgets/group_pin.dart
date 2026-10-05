import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../location/domain/trip_status.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/member_on_map.dart';

/// Groepspin voor leden die op het scherm dicht bij elkaar staan: overlappende
/// avatars (max 3 + "+N"), een statusballon met de meest recente status, en een
/// puntje naar de locatie.
class GroupPin extends StatelessWidget {
  const GroupPin({
    super.key,
    required this.members,
    required this.now,
    this.placeByUser = const {},
    this.myUserId,
    this.selectedUserId,
  });

  static const width = 260.0;
  static const height = 160.0;

  static const _avatar = 72.0;
  static const _step = 48.0;
  static const _maxShown = 3;

  /// Leden in deze groep; de eerste is "ik" (indien aanwezig), die bovenop ligt.
  final List<MemberOnMap> members;
  final DateTime now;
  final Map<String, PlaceStatus> placeByUser;
  final String? myUserId;
  final String? selectedUserId;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(_maxShown).toList();
    final extra = members.length - shown.length;
    final clusterWidth = (shown.length - 1) * _step + _avatar + (extra > 0 ? _step : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Bubble(info: _info(), now: now),
        const SizedBox(height: 4),
        SizedBox(
          width: clusterWidth,
          height: _avatar + 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (extra > 0) Positioned(left: shown.length * _step, child: _plus(extra)),
              // Achterste eerst tekenen; "ik" (index 0) komt zo bovenop.
              for (final (index, member) in shown.indexed.toList().reversed)
                Positioned(left: index * _step, child: _avatarFor(member)),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }

  Widget _avatarFor(MemberOnMap member) {
    final isSelected = member.member.userId == selectedUserId;
    final avatar = MemberAvatar(member: member.member, size: _avatar, ring: !isSelected);
    if (!isSelected) return avatar;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mapSelection),
      child: avatar,
    );
  }

  Widget _plus(int extra) {
    return Container(
      width: _avatar,
      height: _avatar,
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
  ({IconData icon, String title, DateTime? at}) _info() {
    MemberOnMap? latest;
    for (final member in members) {
      final location = member.location;
      if (location == null) continue;
      if (latest == null || location.updatedAt.isAfter(latest.location!.updatedAt)) {
        latest = member;
      }
    }
    if (latest == null) {
      return (icon: Icons.group, title: '${members.length} gezinsleden', at: null);
    }

    final name = latest.member.userId == myUserId ? 'Jij' : latest.member.displayName;
    final place = placeByUser[latest.member.userId];
    if (place != null) {
      return (
        icon: placeIcon(place.icon),
        title: '$name is aangekomen',
        at: place.since ?? latest.location!.updatedAt,
      );
    }
    if (TripStatus.at(latest.location, now).speedKmh != null) {
      return (
        icon: Icons.directions_car_filled_outlined,
        title: '$name is onderweg',
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
        boxShadow: const [BoxShadow(color: Color(0x26121C1C), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  style: text.labelLarge?.copyWith(color: AppColors.ink),
                ),
                if (info.at != null)
                  Text(
                    formatRelative(info.at!, now: now),
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
