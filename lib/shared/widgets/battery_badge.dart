import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Batterij-weergave zoals in de mockups: gewoon icoon + percentage, maar bij
/// een lage stand een opvallende oranje pil. Los van [BatteryIndicator], die de
/// bestaande kaartlijst bedient.
class BatteryBadge extends StatelessWidget {
  const BatteryBadge({super.key, required this.level, this.isCharging});

  static const lowThreshold = 20;

  final int? level;
  final bool? isCharging;

  @override
  Widget build(BuildContext context) {
    final value = level;
    if (value == null) return const SizedBox.shrink();

    final isLow = value <= lowThreshold && isCharging != true;
    final color = isLow ? AppColors.alert : AppColors.primary;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: color);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value%', style: textStyle),
        const SizedBox(width: 4),
        Icon(_icon(value), size: 18, color: color),
      ],
    );

    return Semantics(
      label: 'Batterij $value procent${isCharging == true ? ', aan het opladen' : ''}',
      excludeSemantics: true,
      child: isLow
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const ShapeDecoration(color: AppColors.alertSoft, shape: StadiumBorder()),
              child: content,
            )
          : content,
    );
  }

  IconData _icon(int value) {
    if (isCharging == true) return Icons.battery_charging_full;
    if (value <= lowThreshold) return Icons.battery_alert;
    if (value <= 50) return Icons.battery_3_bar;
    if (value <= 80) return Icons.battery_5_bar;
    return Icons.battery_full;
  }
}
