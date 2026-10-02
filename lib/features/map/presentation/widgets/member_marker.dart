import 'package:flutter/material.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/member_on_map.dart';

class MemberMarker extends StatelessWidget {
  const MemberMarker({super.key, required this.entry});

  static const width = 96.0;
  static const height = 80.0;

  final MemberOnMap entry;

  @override
  Widget build(BuildContext context) {
    final speed = speedKmh(entry.location?.speedMps);
    final label = speed != null ? '$speed km/u' : entry.member.displayName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemberAvatar(member: entry.member, ring: true),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x26121C1C), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
