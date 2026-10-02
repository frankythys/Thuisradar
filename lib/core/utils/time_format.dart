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
