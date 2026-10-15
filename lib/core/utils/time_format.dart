import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import 'calendar.dart';

export 'calendar.dart' show formatClock, isOtherDay;

/// Korte tijdsaanduiding in de taal van de app: "zonet", "5 min geleden",
/// "2 u geleden" of een datum.
String formatRelative(AppLocalizations l10n, DateTime moment, {required DateTime now}) {
  final diff = now.difference(moment);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  return l10n.timeOnDate(_dayMonth(moment));
}

/// Sinds-tijd voor de ledenlijst: "13:03", "16:49 gisteren" of "14:02 op
/// 28/09". Kort genoeg voor een tweede regel naast de status.
String formatSince(AppLocalizations l10n, DateTime moment, {required DateTime now}) {
  final day = DateTime(moment.year, moment.month, moment.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = calendarDaysBetween(day, today);
  final clock = formatClock(moment);
  if (days <= 0) return clock;
  if (days == 1) return l10n.timeClockYesterday(clock);
  return l10n.timeClockOnDate(clock, _dayMonth(moment));
}

/// Duur: "25 min", "1 u", "2 u 15 min".
String formatDuration(AppLocalizations l10n, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return l10n.durationMinutes(minutes);
  if (minutes == 0) return l10n.durationHours(hours);
  return l10n.durationHoursMinutes(hours, minutes);
}

/// Afstand: "850 m" of "2,4 km" (decimaalteken van de taal).
String formatDistance(AppLocalizations l10n, double meters) {
  if (meters < 1000) return l10n.distanceMeters(meters.round());
  return l10n.distanceKm(NumberFormat('0.0', l10n.localeName).format(meters / 1000));
}

/// "Vandaag", "Gisteren" of "ma 6/10": dagkop boven berichten of meldingen.
String formatDayLabel(AppLocalizations l10n, DateTime day, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  final difference = calendarDaysBetween(target, today);
  if (difference == 0) return l10n.dayToday;
  if (difference == 1) return l10n.dayYesterday;
  return l10n.dayShort(l10n.weekdayShort('${target.weekday}'), '${target.day}/${target.month}');
}

/// "28/09": dag en maand met voorloopnul.
String _dayMonth(DateTime moment) =>
    '${moment.day.toString().padLeft(2, '0')}/${moment.month.toString().padLeft(2, '0')}';
