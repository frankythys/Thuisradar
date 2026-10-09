/// Hulpjes om chatberichten per dag te groeperen. Puur en testbaar.
library;

const _weekdays = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];

/// "Vandaag", "Gisteren" of "ma 6/10" boven de berichten van die dag.
String chatDayLabel(DateTime day, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Vandaag';
  if (difference == 1) return 'Gisteren';
  return '${_weekdays[target.weekday - 1]} ${target.day}/${target.month}';
}

/// Begint [current] een nieuwe dag t.o.v. het vorige bericht?
bool startsNewChatDay(DateTime? previous, DateTime current) =>
    previous == null ||
    previous.year != current.year ||
    previous.month != current.month ||
    previous.day != current.day;
