import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

class ParkedCarMarker extends StatelessWidget {
  const ParkedCarMarker({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: tokens.spaceXs / 2),
            boxShadow: tokens.shadowMarker,
          ),
          child: SizedBox(
            width: tokens.spaceXxl,
            height: tokens.spaceXxl,
            child: Icon(Icons.directions_car, color: colors.primary, size: tokens.spaceLg),
          ),
        ),
        SizedBox(height: tokens.spaceXs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            boxShadow: tokens.shadowBubble,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spaceXs, vertical: tokens.spaceXs / 2),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}
