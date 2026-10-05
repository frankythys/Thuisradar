import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/member_on_map.dart';

class MemberMarker extends StatelessWidget {
  const MemberMarker({super.key, required this.entry, required this.now, this.selected = false});

  static const width = 120.0;
  static const height = 96.0;
  static const avatarSize = 64.0;

  final MemberOnMap entry;
  final DateTime now;

  /// Geselecteerd lid: accent-selectiering en iets groter.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.0,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_Avatar(entry: entry, selected: selected)],
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
    final avatar = MemberAvatar(member: entry.member, size: MemberMarker.avatarSize, ring: !selected);
    if (!selected) return avatar;

    // Paars is gereserveerd voor selectie en vervangt de witte rand volledig.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mapSelection,
        boxShadow: context.tokens.shadowLevel2,
      ),
      child: avatar,
    );
  }
}
