/// Pure datumhulpjes zonder taal (bruikbaar in `domain/`).
library;

/// Aantal kalenderdagen van [from] tot [to] (lokale datums, tijd genegeerd).
/// Niet via `difference().inDays` op lokale tijden: de dag van de overgang
/// naar zomertijd duurt 23 uur, en dan werd "gisteren" nog "vandaag".
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Kloktijd als "HH:mm".
String formatClock(DateTime moment) {
  final hour = moment.hour.toString().padLeft(2, '0');
  final minute = moment.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Valt [current] op een andere kalenderdag dan [previous]?
bool isOtherDay(DateTime? previous, DateTime current) =>
    previous == null ||
    previous.year != current.year ||
    previous.month != current.month ||
    previous.day != current.day;
