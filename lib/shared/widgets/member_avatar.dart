import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../features/family/domain/family_member.dart';

/// Vorm van de avatar: rond op de kaart, afgerond vierkant in de ledenlijst.
enum MemberAvatarShape { circle, rounded }

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 44,
    this.ring = false,
    this.statusColor,
    this.shape = MemberAvatarShape.circle,
  });

  final FamilyMember member;
  final double size;

  /// Witte rand + schaduw, voor gebruik op de kaart.
  final bool ring;

  /// Statusstip rechtsonder (bv. groen = online). Verborgen als null.
  final Color? statusColor;

  /// Rond (kaart) of afgerond vierkant (ledenlijst).
  final MemberAvatarShape shape;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = tokens.memberColor(member.colorIndex);
    final square = shape == MemberAvatarShape.rounded;

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.3) : null,
        color: color,
        border: ring ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: ring ? tokens.shadowLevel2 : null,
      ),
      child: Text(
        member.initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );

    if (statusColor == null) return avatar;

    final dot = size * 0.26;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
