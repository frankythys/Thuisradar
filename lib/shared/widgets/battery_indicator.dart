import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key, required this.level, this.isCharging});

  static const lowThreshold = 20;

  final int? level;
  final bool? isCharging;

  @override
  Widget build(BuildContext context) {
    final value = level;
    if (value == null) return const SizedBox.shrink();

    final isLow = value <= lowThreshold && isCharging != true;
    final color = isLow ? AppColors.alert : AppColors.primary;

    return Semantics(
      label: 'Batterij $value procent${isCharging == true ? ', aan het opladen' : ''}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(value), size: 20, color: color),
          const SizedBox(width: 2),
          Text(
            '$value%',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
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
