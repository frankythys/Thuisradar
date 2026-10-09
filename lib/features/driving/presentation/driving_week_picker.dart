import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import 'driving_summary.dart';

/// Week kiezen met pijltjes: ‹ Deze week ›. Hoogstens [maxWeeksBack] terug,
/// nooit verder dan de huidige week.
class DrivingWeekPicker extends StatelessWidget {
  const DrivingWeekPicker({
    super.key,
    required this.week,
    required this.currentWeek,
    required this.onChanged,
    this.maxWeeksBack = 11,
  });

  final DateTime week;
  final DateTime currentWeek;
  final ValueChanged<DateTime> onChanged;
  final int maxWeeksBack;

  int get _weeksBack => currentWeek.difference(week).inDays ~/ 7;

  DateTime _shift(int weeks) => DateTime(week.year, week.month, week.day + 7 * weeks);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final end = _shift(1).subtract(const Duration(days: 1));
    final title = switch (_weeksBack) {
      0 => 'Deze week',
      1 => 'Vorige week',
      final n => '$n weken geleden',
    };
    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceXs, vertical: tokens.spaceXs),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Week ervoor',
            onPressed: _weeksBack >= maxWeeksBack ? null : () => onChanged(_shift(-1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(title, style: text.titleMedium),
                Text(
                  '${drivingDate(week)} – ${drivingDate(end)}',
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Week erna',
            onPressed: _weeksBack <= 0 ? null : () => onChanged(_shift(1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
