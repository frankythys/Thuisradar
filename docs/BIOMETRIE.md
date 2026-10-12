# Vingerscan

Log eenmalig in via Google of e-mail/wachtwoord. Open Profiel en schakel Vingerscan in; bevestig met de geregistreerde vingerafdruk/gezichtsherkenning van het toestel. Vanaf de volgende appstart en bij terugkeer uit de achtergrond is de volledige navigator afgeschermd tot een geslaagde scan. De bestaande Supabase-sessie blijft bestaan en achtergrondlocatie blijft actief. Er worden geen wachtwoorden voor biometrie opgeslagen.

Annuleren en scanfouten geven geen toegang. Bij ontbrekende biometrie kun je kiezen voor Opnieuw inloggen; dit beëindigt de sessie en brengt je terug naar Google/e-mail-login. Expliciet Uitloggen beëindigt ook de biometrische toegang; biometrie is geen vervanging voor een beëindigde serversessie.

De oude wachtwoordgebaseerde optie wordt niet automatisch overgenomen. Schakel Vingerscan opnieuw in via Profiel. De voorkeur is gekoppeld aan het gebruikers-ID en geeft een ander account geen toegang.

Toestelcontrole: Google-login, activeren, app sluiten/openen, annuleren, foutieve scan, correcte scan, profiel/detailpagina open laten en app naar achtergrond/terug, uitloggen en opnieuw aanmelden. Unit/widgettests testen sessie-afscherming en annuleren; een echte sensorcontrole blijft nodig.
