# Vingerscan

Log eenmalig in via Google of e-mail/wachtwoord. Tik op de vingerscan op het inlogscherm en kies Instellen. Log eenmalig in; bevestig met de geregistreerde vingerafdruk/gezichtsherkenning van het toestel. Vanaf de volgende appstart en bij terugkeer uit de achtergrond is de volledige navigator afgeschermd tot een geslaagde scan. De bestaande Supabase-sessie blijft bestaan en achtergrondlocatie blijft actief. Er worden geen wachtwoorden voor biometrie opgeslagen.

Annuleren en scanfouten geven geen toegang. Bij ontbrekende biometrie kun je kiezen voor Opnieuw inloggen; dit beëindigt de sessie en brengt je terug naar Google/e-mail-login. Expliciet Uitloggen beëindigt ook de biometrische toegang; biometrie is geen vervanging voor een beëindigde serversessie.

De oude wachtwoordgebaseerde optie wordt niet automatisch overgenomen. Stel Vingerscan eenmalig in op het inlogscherm. De voorkeur is gekoppeld aan het gebruikers-ID en geeft een ander account geen toegang.

Toestelcontrole: Google-login, activeren, app sluiten/openen, annuleren, foutieve scan, correcte scan, profiel/detailpagina open laten en app naar achtergrond/terug, uitloggen en opnieuw aanmelden. Unit/widgettests testen sessie-afscherming en annuleren; een echte sensorcontrole blijft nodig.

Als Vingerscan aan staat, is de dagelijkse afsluitknop in Profiel **Uitloggen**. Dit meldt de zichtbare app af en bewaart de toestel-login voor biometrie; daarna kom je met een scan terug binnen. **Account volledig afmelden** beëindigt expliciet de serversessie en vereist een nieuwe Google/e-mail-aanmelding. Zo blijven vergrendelen en volledige accountafmelding duidelijk onderscheiden.

## Toegangscode

Via Profiel > Toegangscode stel je twee keer dezelfde code van zes cijfers in. Deze werkt naast of zonder biometrie, ook na de gewone Uitloggen-knop. De code wordt met PBKDF2-HMAC-SHA256, een willekeurige salt en 100.000 iteraties afgeleid; alleen die afgeleide waarde wordt in beveiligde toestelopslag bewaard. Na vijf fouten geldt een wachttijd van 30 seconden die bij volgende fouten oploopt tot maximaal 15 minuten; de teller blijft na een appherstart behouden. Via dezelfde instelling kun je wijzigen of uitschakelen. Bij code vergeten kies je Opnieuw inloggen en meld je aan via Google/e-mail. Volledig afmelden en opgeslagen login verwijderen wissen de toestelcode.
