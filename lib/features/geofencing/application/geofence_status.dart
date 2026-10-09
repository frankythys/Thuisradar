/// Stand van de zonebewaking op dit toestel.
enum GeofenceStatus {
  /// Niet gestart, of delen staat uit.
  idle,

  /// Zones staan bij Android; meldingen komen ook met de app dicht.
  active,

  /// Locatie staat niet op "Altijd toestaan".
  permissionMissing,

  /// Migratie 014 is nog niet gedraaid in Supabase.
  notConfigured,

  /// Iets anders liep mis; de server-detectie werkt wel nog.
  error,
}
