/// Aantal kalenderdagen van [from] tot [to] (lokale datums, tijd genegeerd).
/// Niet via `difference().inDays` op lokale tijden: de dag van de overgang
/// naar zomertijd duurt 23 uur, en dan werd "gisteren" nog "vandaag".
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
