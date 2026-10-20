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
   Voer daarna **elke migratie** in `supabase/migrations/` uit, één per keer en **in
   nummervolgorde** (`002_…` tot en met de hoogste, nu `024_leave_family.sql`). Zonder de
   migraties ontbreken SOS, push, plaatsen, chat, noodcontacten, parkeerplek en het
   veilig verlaten van een gezin.
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
4. Locatie toestaan → kies eerst **"Tijdens gebruik van de app"** en daarna, als de app
   erom vraagt, **"Altijd toestaan"**. Zonder "Altijd toestaan" stopt het delen zodra de
   app op de achtergrond gaat, en werken aankomst/vertrek bij plaatsen niet. Er verschijnt
   een vaste melding *"Je locatie wordt gedeeld met je familie"* zolang er gedeeld wordt.

## APK maken voor de gsm van je zoon

```
flutter build apk --release --dart-define-from-file=env.json
```

Het bestand staat in `build\app\outputs\flutter-apk\app-release.apk`. Zet het op de gsm
en installeer het (Android vraagt om "installeren uit onbekende bronnen" toe te staan).

> Zonder `android/key.properties` wordt de release met de **debug-sleutel** ondertekend
> (de Gradle-uitvoer meldt dat). Prima voor de familie, maar Google Play weigert zo'n bundle.

## Release voor Google Play (upload-sleutel)

Google Play wil een bundle (`.aab`) die met **jouw eigen upload-sleutel** ondertekend is.
Met *Play App Signing* (standaard bij een nieuwe app) ondertekent Google de app daarna
zelf opnieuw; de upload-sleutel bewijst alleen dat de upload van jou komt.

**1. Keystore maken (eenmalig).** In een terminal in de projectmap (keytool zit bij de
JDK van Android Studio of Adoptium). De keystore komt in `android\app`; elk `.jks`-bestand
staat in `.gitignore`, dus hij gaat nooit mee naar GitHub:

```
keytool -genkeypair -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

keytool vraagt een wachtwoord (kies een sterk wachtwoord) en je naam/organisatie
(gewoon je naam en `BE` mag). Bij dit standaardformaat (PKCS12) is het
sleutelwachtwoord hetzelfde als het keystore-wachtwoord.

**2. Back-up maken.** Omdat de keystore niet in git zit, staat hij enkel op deze pc (en
niet op de laptop na Ctrl+T). Zet het `.jks`-bestand én het wachtwoord daarom ook in je
wachtwoordbeheerder of op een USB-stick. Nooit in git, nooit in een chat of mail. Kwijt? Met
Play App Signing kan je in de Play Console een nieuwe upload-sleutel aanvragen, maar dat
duurt een paar dagen.

**3. `android/key.properties` maken.** Kopieer `android/key.properties.example` naar
`android/key.properties` (staat in `.gitignore`) en vul je wachtwoord in. `storeFile` is
relatief aan `android/app`:

```
storeFile=upload-keystore.jks
storePassword=<je wachtwoord>
keyAlias=upload
keyPassword=<je wachtwoord>
```

**4. Bundle bouwen:**

```
flutter build appbundle --release --dart-define-from-file=env.json
```

De bundle staat in `build\app\outputs\bundle\release\app-release.aab`; die upload je
in de Play Console. Controleren met welke sleutel hij ondertekend is:
`keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab`
(je ziet de naam die je bij stap 1 invulde, niet "Android Debug").

> **Let op bij de gsm's van de familie:** een APK met de upload-sleutel kan niet over een
> APK met de debug-sleutel heen geïnstalleerd worden ("App niet geïnstalleerd"). Dan
> eerst de oude app verwijderen (opnieuw inloggen en toestemmingen geven) of de app
> voortaan via Google Play installeren.

## Bekende aandachtspunten

| Probleem | Oplossing |
|---|---|
| Locatie stopt na een tijdje | Samsung/Xiaomi/Huawei: *Instellingen > Apps > Thuisradar > Batterij* → **Onbeperkt** |
| Geen vaste melding zichtbaar (Android 13+) | *Instellingen > Apps > Thuisradar > Meldingen* aanzetten |
| `SUPABASE_URL ... ontbreekt` bij starten | `--dart-define-from-file=env.json` ontbreekt in de Run-configuratie |
| Familie laden mislukt | Zijn `supabase/schema.sql` én alle migraties uitgevoerd? |
| `failed to strip debug symbols` bij `flutter build appbundle` | De `.aab` is wel gemaakt, maar Flutter kan hem niet nakijken: *Android Studio > Settings > Languages & Frameworks > Android SDK > SDK Tools* → **Android SDK Command-line Tools (latest)** aanvinken, daarna `flutter doctor --android-licenses` |
| Gradle-fout bij eerste build | `flutter doctor` controleren, daarna **File > Invalidate Caches** |

## Mama's iPhone

Later: of de app via een clouddienst (Codemagic) voor iOS bouwen
(Apple Developer-account nodig), of OwnTracks koppelen aan dezelfde Supabase-database.
