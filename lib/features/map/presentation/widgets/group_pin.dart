import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/member_on_map.dart';

/// Groepspin voor leden die op het scherm dicht bij elkaar staan: overlappende
/// avatars (max 3 + "+N"), een statusballonnetje en een puntje naar de locatie.
class GroupPin extends StatelessWidget {
  const GroupPin({super.key, required this.members, required this.now, this.myUserId, this.selectedUserId});

  static const width = 200.0;
  static const height = 110.0;

  static const _avatar = 40.0;
  static const _step = 26.0;
  static const _maxShown = 3;

  /// Leden in deze groep; de eerste is "ik" (indien aanwezig), die bovenop ligt.
  final List<MemberOnMap> members;
  final DateTime now;
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
        _bubble(context),
        const SizedBox(height: 4),
        SizedBox(
          width: clusterWidth,
          height: _avatar + 8,
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
    final isMe = member.member.userId == myUserId;
    final isSelected = member.member.userId == selectedUserId;
    final avatar = MemberAvatar(member: member.member, size: _avatar, ring: true);
    if (!isMe && !isSelected) return avatar;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: isSelected ? 3 : 2),
      ),
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  Widget _bubble(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x26121C1C), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        _statusText(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Meest recente status binnen de groep. (D2 vervangt dit door plaatsen,
  /// bv. "Liam is aangekomen · 15 u geleden".)
  String _statusText() {
    MemberOnMap? latest;
    for (final member in members) {
      final location = member.location;
      if (location == null) continue;
      if (latest == null || location.updatedAt.isAfter(latest.location!.updatedAt)) {
        latest = member;
      }
    }
    if (latest == null) return '${members.length} gezinsleden';

    final name = latest.member.userId == myUserId ? 'Jij' : latest.member.displayName;
    return '$name · ${formatRelative(latest.location!.updatedAt, now: now)}';
  }
}
