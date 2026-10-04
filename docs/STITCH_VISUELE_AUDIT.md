# Visuele Stitch-audit — 4 oktober 2026

Bron: `assets/UI_screens_stitch/stitch_thuisradar_family_tracker_ui/`, per scherm `screen.png` en `code.html`.

De beelden in `build/stitch-audit/emulator/` zijn van de vorige sessie, vóór de laatste aanpassingen. De contactbladen `references.png` en `current.jpg` zijn in deze sessie visueel bekeken. Kaarttegels waren daadwerkelijk geladen. De emulator had 448 logische pixels breedte, wat afwijkt van sommige mockups. Hieronder staat wat is bekeken en vervolgens aangepast; dit is **geen bewijs van een exacte match van de laatste code**. Nieuwe build/screenshotcontrole is op verzoek aan de gebruiker overgedragen.

| Scherm | Bevinding / aanpassing |
|---|---|
| 1 Veilig thuis | Radar/ledenpins, titel, privacykaart en footer aanwezig; verticale verhouding nog vergelijken. |
| 2 Alleen familie | Aangeleverde SVG, voordelenkaarten en voortgang aanwezig; onbewezen E2E-claim gecorrigeerd. |
| 3 Meldingen | Telefoonillustratie, bericht, titel en footer aanwezig. |
| 4 Hulp | Noodillustratie, drie contacten, uitleg en codeactie aanwezig. |
| 5 Registreren | Logo, privacychip, naam/e-mail/wachtwoord, privacykaart en accountactie aanwezig. |
| 6 Inloggen | Witte kaart, herstelactie en biometrieknop; biometrie nu echt aangesloten. |
| 7 Familie kiezen | Twee keuzevakjes en codeplakken; invoer nu acht visuele vakjes. |
| 8 Uitnodigen | Succeshero, code, stappenkaart; WhatsApp- en kopieeractie aangepast. |
| 9 Welkom | Ledenkaart aanwezig; hero-pins en echte batterijstanden toegevoegd. |
| 10 Toestemmingen | Drie rechtenkaarten en privacykaart; spacing compacter, footer apart te controleren. |
| 11 Kaart | Tegels/markers aanwezig; lijst vergroot voor drie leden en check-in, beheer toegevoegd. |
| 12 Gezinslid | Kaart, stats, tijdlijn aanwezig; 30 dagen, laatst gezien en contactacties toegevoegd. |
| 13 Plaatsen | Plaatskaarten, aanwezigheid, meldingspillen en toevoegen aanwezig; delete regressie getest. |
| 14 Toevoegen | Kaart/zone/adres aanwezig; onjuist adres bij kaartbeweging opgelost; onderste switches apart te controleren. |
| 15 Meldingen | Filterchips, lage batterij en gebeurteniskaarten aanwezig; datumgroepen/onderdelen nog vergelijken. |
| 16 Chat | Gezinsheader en locatiekaart aanwezig; foto, spraak en belactie toegevoegd. |
| 17 SOS versturen | Holdknop, ontvangers, noodmodus en 112 aanwezig; onderkant apart te controleren. |
| 18 SOS ontvangen | Urgentkaart, route en onderweg aanwezig; echte ontvangststatus, bellen en actuele locatie toegevoegd. |
| 19 Profiel | Kleur/delen/familie aanwezig; instellingen onder vouw, telefoon en biometriebeheer toegevoegd. |
| 20 Leeg/offline | Lege kaart aanwezig; afzonderlijke offlineledenkaart, retrybanner en vijf navigatieacties toegevoegd. |

Openstaande visuele eindcontrole: nieuwe beelden op gelijke logische breedte; alle scrolldelen; 360-pixelbreedte en vergrote tekst. Werkende native bediening vraagt een echte build met de uitgerolde backend. Er is geen nieuwe release-APK gemaakt in deze vervolgsessie.
