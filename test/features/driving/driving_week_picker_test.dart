import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/driving/presentation/driving_week_picker.dart';

void main() {
  final current = DateTime(2026, 10, 5);

  Future<DateTime?> pump(WidgetTester tester, DateTime week) async {
    DateTime? changed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DrivingWeekPicker(week: week, currentWeek: current, onChanged: (w) => changed = w),
        ),
      ),
    );
    return changed;
  }

  testWidgets('deze week: terug kan, vooruit niet', (tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DrivingWeekPicker(week: current, currentWeek: current, onChanged: (w) => changed = w),
        ),
      ),
    );
    expect(find.text('Deze week'), findsOneWidget);
    expect(find.text('5/10 – 11/10'), findsOneWidget);
    await tester.tap(find.byTooltip('Week erna'));
    expect(changed, isNull);
    await tester.tap(find.byTooltip('Week ervoor'));
    expect(changed, DateTime(2026, 9, 28));
  });

  testWidgets('vorige week en verder terug krijgen een duidelijke naam', (tester) async {
    await pump(tester, DateTime(2026, 9, 28));
    expect(find.text('Vorige week'), findsOneWidget);
    await pump(tester, DateTime(2026, 9, 14));
    expect(find.text('3 weken geleden'), findsOneWidget);
  });
}
