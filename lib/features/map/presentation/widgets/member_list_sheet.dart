import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/member_on_map.dart';
import 'member_tile.dart';

/// Uitschuifbaar paneel met alle gezinsleden onder de kaart.
class MemberListSheet extends StatelessWidget {
  const MemberListSheet({
    super.key,
    required this.members,
    required this.currentUserId,
    required this.now,
    required this.onSelect,
  });

  final List<MemberOnMap> members;
  final String? currentUserId;
  final DateTime now;
  final ValueChanged<MemberOnMap> onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.14,
      maxChildSize: 0.8,
      snap: true,
      builder: (context, scrollController) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Color(0x1A121C1C), blurRadius: 24, offset: Offset(0, -6))],
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                'Familie · ${members.length} ${members.length == 1 ? 'lid' : 'leden'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final entry in members)
              MemberTile(
                entry: entry,
                isMe: entry.member.userId == currentUserId,
                now: now,
                onTap: () => onSelect(entry),
              ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}
