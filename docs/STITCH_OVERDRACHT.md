# Stitch-overdracht — 4 oktober 2026

## Laatste gebruikersbevestiging
- Gebruiker bevestigt dat het geluid werkt; de telefoon stond op stil.
- Gebruiker vraagt alle wijzigingen te committen en pushen. Codecommit `93787f9` stond al op `origin/main`; werkmap was schoon. Deze bevestiging wordt apart vastgelegd en gepusht.

## Aanvulling — chatpush en meldingsgeluiden
- Gebruiker meldde geen/zacht geluid bij chat, SOS en thuiskomst. Op aangesloten Samsung stond STREAM_NOTIFICATION gedempt; alarmstream niet gedempt (12/15), Niet storen uit. Algemene toestelinstellingen niet gewijzigd.
- Chatpush ontbrak. Migratie 012 en `send-chat-push` zijn nu uitgerold: nieuwe berichten (ook bijlagen/check-ins) melden aan andere gezinsleden; geen berichtinhoud/bijlagepad op vergrendelscherm. Trigger gecontroleerd met onderschepte `private.call_push` in BEGIN/ROLLBACK: geen echte push of blijvend testbericht.
- Nieuw kanaal `chat_messages` met eigen korte toon; SOS-kanaal `sos_alerts_v2` met oorspronkelijke gegenereerde alarmtoon van 4,5 seconden via alarmvolume. Android-resources en generator in git; keep.xml voorkomt verwijderen bij resource shrinking.
- `device_tokens.notification_version` zorgt dat oude installaties bestaande kanalen/geluiden blijven gebruiken. Nieuwe app registreert versie 2 nadat de kanalen zijn gemaakt. Nieuwe geluiden vereisen gebruikersbuild/installatie én eenmaal openen.
- Plaatsenpush heeft nu hoge afleverprioriteit; geluid blijft een gewone melding en volgt stilstand/meldingsvolume van Android. SOS respecteert nog steeds blokkades/Niet storen; geen gegarandeerde doorbraak of continue sirene.
- Pushregistratie bij reeds herstelde sessies hersteld; in-/uitloggen wordt sequentieel afgehandeld. Voorgrondmeldingen onderscheiden chat/SOS/plaatsen en de listener wordt opgeruimd.
- Alle drie pushfuncties verwijderen alleen expliciet verlopen FCM-tokens en tellen afleverfouten niet langer als succes. Webhookgeheim blijft vereist.
- Verificatie: 101 Flutter-tests geslaagd; analyzer schoon; drie Edge Functions typechecked; twee Deno-tests met gemockte netwerkverzoeken geslaagd (ontvangers, afzender uitsluiten, privacy, oude app, fouten); migratie uitgerold en aanwezigheid bevestigd; chat-endpoint weigert verzoek zonder geheim met 401.
- Geen APK-/emulatorbuild, visuele controle, hoorbare toesteltest of echte gezinsmelding uitgevoerd. Gebruiker bouwt/test; voor chat/plaatsen moet meldingsgeluid op het toestel aanstaan.

## Aanvulling — kaartstart en horizontaal schuiven
- Kaart centreert bij openen één keer op de ingelogde persoon, zodra diens locatie beschikbaar is, met overzichtszoom 12 en ruimte voor de ledenlijst. Locaties van andere leden nemen de startfocus niet over.
- Na handmatig schuiven/zoomen springt de kaart niet automatisch terug. De bestaande centreerknop toont nog steeds het gezin samen.
- De beperking tot lengtegraad -180/+180 is vervangen door uitsluitend een verticale begrenzing: links/rechts kan de wereldkaart nu doorlopen.
- 14 gerichte kaarttests geslaagd, inclusief eigen startlocatie en beide wereldranden. Geen build of visuele controle uitgevoerd.

## Aanvulling — inloggegevens onthouden
- Gebruiker bevestigt: builds én visuele controle blijven bij gebruiker.
- Gewoon inloggen heeft nu ‘Inloggegevens onthouden’ (standaard aan): e-mailadres (de loginnaam) en wachtwoord worden uitsluitend na geslaagde login versleuteld op het toestel opgeslagen en bij het volgende loginscherm ingevuld. Wachtwoord blijft verborgen.
- Uitvinken verwijdert de onthouden gegevens; profielactie verwijdert zowel onthouden gegevens als biometrische login.
- Na geslaagde gewone login wordt een bestaande biometrische login van hetzelfde account bijgewerkt met het actuele wachtwoord. Een ander account verwijdert de oude biometrische login.
- Biometrische login bewaart ook de gegevens volgens de onthouden-keuze. Annuleren van de biometrische prompt leest geen credentials en logt niet in.
- Controle: 9 gerichte auth-tests geslaagd; flutter analyze schoon. Geen APK-/emulatorbuild of visuele controle uitgevoerd. Biometrische hardware blijft op toestel te controleren.
- Wachtwoordherstel/deeplink-flow blijft een afzonderlijk open codepunt; deze aanvulling implementeert die flow niet.

## Opdracht en laatste gebruikerssturing
- Project: `C:\Programming\Thuisradar`, branch `main`, remote `origin` (frankythys/Thuisradar).
- Oorspronkelijk: alle 20 schermen zoals de Stitch-mockups; plaatsen verwijderen herstellen; controleren, committen en pushen zonder vragen.
- Laatste instructies: chat kort houden, dit md-bestand na geslaagde stappen bijwerken. **Gebruiker doet de build zelf. Geen APK-/emulatorbuild opnieuw starten zonder nieuwe instructie.**
- Geen nieuwe taak of subagents aangemaakt. Geen echte chatberichten, noodoproepen of testpushes verstuurd.

## Huidige code
- Mint/teal thema, Jakarta-lettertype, native radarlogo, aangepaste navigatie en vier onboardingillustraties.
- Registratie/inloggen met herstelmail. Echte biometrische login via local_auth en versleutelde toestelopslag: inschakelen vraagt expliciete toestemming; opgeslagen login kan via profiel verwijderd worden. Android gebruikt FragmentActivity/AppCompat en backup staat uit.
- Familie kiezen met acht codevakjes en plakken; uitnodigen via WhatsApp/deelmenu; welkomsthero en werkelijke batterijgegevens; toestemmingen en privacy-/profielacties.
- Kaart met SOS-scherm, grotere ledenlijst, beheer, check-in naar familiechat, lege-locatieskaart, offlineledenkaart en vijf navigatieacties in lege/offlinestaat.
- Detail met kaart/route, batterij/laatst gezien/afstand, vandaag/gisteren/30 dagen, bericht/bel-/meldingsacties. Historiequery gebruikt paginering.
- Plaatsen met adres, ledenkeuze, straal en aankomst-/vertrekvoorkeuren. Delete vraagt teruggegeven id: geen stilzwijgend succes; verwijderde plaats verdwijnt meteen, fout behoudt de kaart.
- Adresselectie bewaart uitsluitend geslaagde zoekresultaten. Kaartbeweging/tekstwijziging maakt oud adres ongeldig; late zoek- en GPS-resultaten overschrijven geen nieuwe keuze.
- Meldingen met filters, gelezenstatus en lagebatterijkaart uit locatiegegevens.
- Chat met locatie delen, foto-preview/bevestiging, spraakopname/stop/versturen/verwijderen, private bijlagen en audio afspelen; belactie via gedeeld telefoonnummer.
- SOS ontvangen met actuele locatie/batterij, bellen, route, echte ontvangststatus en onderwegbevestiging.
- Profiel met kleur, persistent delen pauzeren, familiecode, servervoorkeuren, naam, optioneel telefoonnummer en biometrische login verwijderen.
- LocationTracker heeft een generation-guard: stoppen/uitloggen tijdens voorkeuren, toegang of batterijmeting hervat/uploadt niet alsnog.
- Private UI-componenten uit grote schermen naar aparte Dart-parts verplaatst; sommige hoofdbuild-methodes blijven groot.
- Onterechte E2E-claims vervangen door besloten gezinskring; een statisch gedeeld chatpunt heet geen live-locatie.

## Backend — blijvend uitgerold
- Migratie 009: `places.address`, `notify_arrival`, `notify_departure`; geofencefunctie respecteert beide keuzes.
- Migratie 010: `profiles.color_index`, eigen-gebruiker-RLS voor `notification_preferences`.
- Migratie 011: optioneel `profiles.phone`, private `family-media` bucket (10 MB, toegestane media), gezinsleesrechten/eigen upload, `sos_receipts` met eigen schrijf-/gezinsleesrechten en realtime.
- Alle drie samen eerst in BEGIN/ROLLBACK gevalideerd, daarna in één transactie toegepast.
- Authenticated regressieproef: voorkeuren, tijdelijke plaats en bijlage; eigen toegang en opslag gecontroleerd, verwijderen gecontroleerd; buitenstaander kan geen media/voorkeuren lezen. Alles van de proef teruggedraaid.
- `send-place-push` en `send-sos-push` typechecked met Deno 2.9.6 en gedeployed; webhookgeheim blijft de authenticatie.
- Eindquery bevestigt alle nieuwe tabellen/velden en private bucket aanwezig.
- **Remote migratiehistorie was leeg doordat eerdere SQL handmatig was toegepast. Niet blind `supabase db push` uitvoeren.** Deze sessie gebruikte `supabase db query --linked --file`.

## Controles
- Volledige unit/widget-run: 92 tests geslaagd (inclusief delete, drie tracker-races, drie adresselectiecases en drie biometriecases).
- `flutter analyze`: definitieve eindrun schoon — No issues found (build/stitch-audit/analyze-final.log).
- `deno check` voor beide edgefuncties geslaagd.
- SQL-validatie en RLS-proeven geslaagd; deployment geslaagd; `git diff --check` zonder whitespacefouten.
- Logs: `build/stitch-audit/{unit-final,analyze-final,edge-check,backend-regression,backend-deploy,backend-final,deploy-place,deploy-sos}.log` (genegeerd in git).

## Visuele status en wat de gebruiker nog moet verifiëren
- Vorige sessie maakte emulatorbeelden van alle 20 schermen; in deze sessie bekeken. **Kaarttegels zijn zichtbaar.** Zie `docs/STITCH_VISUELE_AUDIT.md`.
- Nieuwe emulatorrun liep vast op `adb shell getprop`; emulator koud herstart. Geen nieuwe screenshots van de laatste wijzigingen geproduceerd. Daarna vroeg gebruiker zelf te bouwen; buildwerk gestopt.
- **Geen pixelgelijke match bevestigd.** Nieuwste layout, native plugins en onderste scrolldelen moeten nog op de gebouwde app gecontroleerd worden.
- Fixtures bevatten fictieve gezinsgegevens, adressen naar Gent gecorrigeerd. Extra screenshotcases voor onderkant toestemmingen/detail/plaatsen/toevoegen/SOS/profiel toegevoegd.
- Nog praktisch te controleren: biometrie op toestel met ingestelde vingerafdruk, foto/spraak upload en afspelen met gezinsaccounts, telefoon-app, native geocoding, klein scherm/tekstvergroting, locatievoorkeuren en SOS-status.
- Controleer ook wachtwoordherstel/deeplink-afhandeling: een herstelmail versturen is aanwezig; volledige recoveryflow is niet in deze sessie bewezen.

## Commando's voor de gebruiker
```powershell
cd C:\Programming\Thuisradar
C:\Programming\flutter\bin\flutter.bat analyze
C:\Programming\flutter\bin\flutter.bat test
C:\Programming\flutter\bin\flutter.bat run --dart-define-from-file=env.json
# Optionele fixture-screenshots op een werkende emulator:
C:\Programming\flutter\bin\flutter.bat drive --driver=test_driver/stitch_driver.dart --target=integration_test/stitch_screens_test.dart -d emulator-5554
```
- Screenshots zijn telkens de laatste handeling van een integration-test wegens Android surface-conversie.
- Geheimen staan in genegeerde `env.json`, `google-services.json` en Supabase-tempconfig; nooit committen.
- Codecommit `0efd67a` is succesvol gepusht naar `origin/main`. Deze definitieve overdracht volgt als kleine documentatiecommit. Analyzer schoon, 92 tests geslaagd, backend uitgerold. Build en nieuwste visuele controle blijven bij gebruiker.
