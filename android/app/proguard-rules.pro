# Regels voor de verkleinde release-build (R8). Flutter neemt dit bestand
# automatisch mee (zie FlutterPlugin.kt: proguard-rules.pro in android/app).

# WorkManager (gebruikt door native_geofence voor de zonebewaking) maakt zijn
# Room-database via reflectie aan. Zonder deze regels gooit R8 de lege
# constructor weg en crasht de app meteen bij het opstarten:
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
