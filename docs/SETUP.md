# Thuisradar installeren (Windows + Android)

## 1. Programma's installeren (eenmalig)

1. **Git**: https://git-scm.com/download/win
2. **Android Studio**: https://developer.android.com/studio
   Open het één keer en laat de *Setup Wizard* de Android SDK installeren.
3. **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows/mobile
   - Pak uit naar `C:\Programming\flutter` (géén map met spaties of `Program Files`).
   - Voeg `C:\Programming\flutter\bin` toe aan je **Path** (Windows: *Omgevingsvariabelen*).
4. In Android Studio: **Settings > Plugins > Marketplace** → installeer **Flutter**
   (Dart komt automatisch mee) → herstart.
5. Open een nieuwe opdrachtprompt en controleer:
   ```
   flutter doctor --android-licenses
   flutter doctor
   ```
   Alles bij *Flutter* en *Android toolchain* moet groen zijn.

## 2. Project ophalen

```
cd C:\Programming
git clone https://github.com/frankythys/thuisradar.git
cd thuisradar
flutter pub get
```

Open daarna in Android Studio: **File > Open** → `C:\Programming\thuisradar`.

## 3. Supabase opzetten (gratis)

1. Maak een account op https://supabase.com → **New project**
   (regio: *West EU (Ireland)* of *Central EU (Frankfurt)*). Bewaar het databasewachtwoord
   in je wachtwoordbeheerder.
2. **SQL Editor > New query** → plak de volledige inhoud van `supabase/schema.sql` → **Run**.
   Je moet "Success. No rows returned" zien.
3. **Authentication > Sign In / Providers > Email**:
   - *Enable Email provider*: aan.
   - *Confirm email*: **uitzetten** is het eenvoudigst voor een familie-app
     (anders moet iedereen eerst op een link in de mail klikken).
4. **Project Settings > API Keys**: kopieer de **Project URL** en de **publishable key**
   (`sb_publishable_...`; bij oudere projecten de **anon public** key).
   ⚠️ Gebruik **nooit** de `service_role`/`secret` key in de app.

## 4. Sleutels invullen

Kopieer `env.example.json` naar **`env.json`** (in dezelfde map) en vul in:

```json
{
  "SUPABASE_URL": "https://abcdefgh.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

`env.json` staat in `.gitignore` en wordt dus nooit mee naar GitHub gepusht.

## 5. Starten vanuit Android Studio

1. **Run > Edit Configurations…** → kies `main.dart` →
   bij **Additional run args** zet je:
   ```
   --dart-define-from-file=env.json
   ```
2. Telefoon aansluiten:
   - *Instellingen > Over de telefoon* → tik 7× op **Buildnummer** (ontwikkelaarsopties).
   - *Ontwikkelaarsopties* → **USB-foutopsporing** aan → USB-kabel in, toestaan.
3. Kies je telefoon bovenaan in Android Studio en druk op ▶ **Run**.

## 6. Eerste keer gebruiken

1. **Account aanmaken** met naam (bv. "Papa"), e-mail en wachtwoord.
2. **Familie aanmaken** → tik linksboven op de familienaam → **Gezinslid uitnodigen**
   kopieert de code.
3. Op de gsm van je zoon: app installeren, account aanmaken, **Familie joinen** met de code.
4. Locatie toestaan → kies **"Tijdens gebruik van de app"**. Er verschijnt een vaste melding
   *"Je locatie wordt gedeeld met je familie"*: zolang die er staat, wordt de locatie
   ook op de achtergrond gedeeld.

## APK maken voor de gsm van je zoon

```
flutter build apk --release --dart-define-from-file=env.json
```

Het bestand staat in `build\app\outputs\flutter-apk\app-release.apk`. Zet het op de gsm
en installeer het (Android vraagt om "installeren uit onbekende bronnen" toe te staan).

> Voor nu gebruikt de release-build de debug-sleutel. Prima voor de familie;
> voor de Play Store is later een eigen signing key nodig.

## Bekende aandachtspunten

| Probleem | Oplossing |
|---|---|
| Locatie stopt na een tijdje | Samsung/Xiaomi/Huawei: *Instellingen > Apps > Thuisradar > Batterij* → **Onbeperkt** |
| Geen vaste melding zichtbaar (Android 13+) | *Instellingen > Apps > Thuisradar > Meldingen* aanzetten |
| `SUPABASE_URL ... ontbreekt` bij starten | `--dart-define-from-file=env.json` ontbreekt in de Run-configuratie |
| Familie laden mislukt | Is `supabase/schema.sql` volledig uitgevoerd? |
| Gradle-fout bij eerste build | `flutter doctor` controleren, daarna **File > Invalidate Caches** |

## Mama's iPhone

Later: of de app via een clouddienst (Codemagic) voor iOS bouwen
(Apple Developer-account nodig), of OwnTracks koppelen aan dezelfde Supabase-database.
