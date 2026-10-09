/// Hulpjes om chatberichten per dag te groeperen. Puur en testbaar; de logica
/// zelf staat in `time_format.dart` en wordt ook door Meldingen gebruikt.
library;

import '../../../core/utils/time_format.dart';

/// "Vandaag", "Gisteren" of "ma 6/10" boven de berichten van die dag.
String chatDayLabel(DateTime day, {required DateTime now}) => formatDayLabel(day, now: now);

/// Begint [current] een nieuwe dag t.o.v. het vorige bericht?
bool startsNewChatDay(DateTime? previous, DateTime current) => isOtherDay(previous, current);
