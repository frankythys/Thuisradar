/// Korte, Nederlandstalige tijdsaanduiding: "zonet", "5 min geleden",
/// "2 u geleden" of een datum.
String formatRelative(DateTime moment, {required DateTime now}) {
  final diff = now.difference(moment);
  if (diff.inMinutes < 1) return 'zonet';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
  if (diff.inHours < 24) return '${diff.inHours} u geleden';

  final day = moment.day.toString().padLeft(2, '0');
  final month = moment.month.toString().padLeft(2, '0');
  return 'op $day/$month';
}

/// Snelheid in km/u, afgerond; null als stilstaand of onbekend.
int? speedKmh(double? metersPerSecond) {
  if (metersPerSecond == null || metersPerSecond < 1.5) return null;
  return (metersPerSecond * 3.6).round();
}

/// Kloktijd als "HH:mm".
String formatClock(DateTime moment) {
  final hour = moment.hour.toString().padLeft(2, '0');
  final minute = moment.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Duur in het Nederlands: "25 min", "1 u", "2 u 15 min".
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours u';
  return '$hours u $minutes min';
}

/// Afstand: "850 m" of "2,4 km" (komma als decimaalteken).
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
