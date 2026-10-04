import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Batterij-weergave zoals in de mockups: gewoon icoon + percentage, maar bij
/// een lage stand een opvallende oranje pil. Los van [BatteryIndicator], die de
/// bestaande kaartlijst bedient.
class BatteryBadge extends StatelessWidget {
  const BatteryBadge({
    super.key,
    required this.level,
    this.isCharging,
    this.compact = false,
  });

  static const lowThreshold = 20;

  final int? level;
  final bool? isCharging;

  /// Compacte variant voor over de avatar (ledenlijst).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = level;
    if (value == null) return const SizedBox.shrink();
    if (compact) return _compact(value);

    final isLow = value <= lowThreshold && isCharging != true;
    final color = isLow ? AppColors.alert : AppColors.primary;
    final textStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: color);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value%', style: textStyle),
        const SizedBox(width: 4),
        Icon(_icon(value), size: 18, color: color),
      ],
    );

    return Semantics(
      label:
          'Batterij $value procent${isCharging == true ? ', aan het opladen' : ''}',
      excludeSemantics: true,
      child: isLow
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const ShapeDecoration(
                color: AppColors.alertSoft,
                shape: StadiumBorder(),
              ),
              child: content,
            )
          : content,
    );
  }

  /// Kleine witte pil met batterij-icoon + percentage, zoals over de avatar in
  /// de ledenlijst ("▮ 65%").
  Widget _compact(int value) {
    final isLow = value <= lowThreshold && isCharging != true;
    final color = isLow ? AppColors.alert : AppColors.primary;

    return Semantics(
      label:
          'Batterij $value procent${isCharging == true ? ', aan het opladen' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4E1E9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11,
              height: 16,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    top: 0,
                    child: Container(width: 5, height: 2, color: AppColors.ink),
                  ),
                  Container(
                    width: 11,
                    height: 14,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: value.clamp(0, 100) / 100,
                        widthFactor: 1,
                        child: ColoredBox(
                          color: isLow ? color : const Color(0xFF74E8B1),
                        ),
                      ),
                    ),
                  ),
                  if (isCharging == true)
                    const Positioned(
                      bottom: 1,
                      child: Icon(Icons.bolt, size: 12, color: AppColors.ink),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value%',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
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
