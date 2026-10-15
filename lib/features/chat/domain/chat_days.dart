/// Hulpje om chatberichten per dag te groeperen. Puur en testbaar; de dagkop
/// zelf ("Vandaag", "ma 6/10") komt uit `formatDayLabel` in de taal van de app.
library;

import '../../../core/utils/calendar.dart';

/// Begint [current] een nieuwe dag t.o.v. het vorige bericht?
bool startsNewChatDay(DateTime? previous, DateTime current) => isOtherDay(previous, current);
