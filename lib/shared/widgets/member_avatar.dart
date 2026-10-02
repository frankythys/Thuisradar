import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/family/domain/family_member.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.size = 44, this.ring = false});

  final FamilyMember member;
  final double size;

  /// Witte rand + schaduw, voor gebruik op de kaart.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.forMemberIndex(member.colorIndex),
        border: ring ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: ring
            ? const [BoxShadow(color: Color(0x40121C1C), blurRadius: 12, offset: Offset(0, 4))]
            : null,
      ),
      child: Text(
        member.initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
  }
}
