import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../places/domain/place_status.dart';
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
    required this.onDetails,
    this.selectedUserId,
    this.placeByUser = const {},
    this.controller,
    this.onCheckIn,
    this.onManage,
  });

  final List<MemberOnMap> members;
  final VoidCallback? onCheckIn;
  final VoidCallback? onManage;
  final String? currentUserId;
  final String? selectedUserId;
  final Map<String, PlaceStatus> placeByUser;
  final DateTime now;

  /// Laat de ouder het paneel programmatisch in-/uitschuiven.
  final DraggableScrollableController? controller;

  /// Tik op een lid: beweeg de kaart ernaartoe.
  final ValueChanged<MemberOnMap> onSelect;

  /// Chevron: open het detailscherm van dat lid.
  final ValueChanged<MemberOnMap> onDetails;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.48,
      minChildSize: 0.14,
      maxChildSize: 0.8,
      snap: true,
      builder: (context, scrollController) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A121C1C),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Familie · ${members.length} ${members.length == 1 ? 'lid' : 'leden'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onManage != null)
                    TextButton(
                      onPressed: onManage,
                      child: const Text('Beheer'),
                    ),
                ],
              ),
            ),
            for (final entry in members)
              MemberTile(
                entry: entry,
                isMe: entry.member.userId == currentUserId,
                now: now,
                selected: entry.member.userId == selectedUserId,
                placeStatus: placeByUser[entry.member.userId],
                onTap: () => onSelect(entry),
                onDetails: () => onDetails(entry),
              ),
            if (onCheckIn != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iedereen veilig',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Laat weten dat het goed gaat',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onCheckIn,
                      child: const Text('Check-in →'),
                    ),
                  ],
                ),
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
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
