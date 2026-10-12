# Google-login instellen

De knop **Doorgaan met Google** werkt voor bestaande en nieuwe accounts via Supabase OAuth. Op Android en iOS opent de browser en keert de gebruiker via een deep link terug. Supabase verwerkt de sessie; de bestaande AuthGate opent daarna de app en maakt zo nodig het profiel aan. Google-wachtwoorden worden niet in de app opgeslagen.

1. Maak in Google Cloud een OAuth-client van type **Web application** en configureer het consent screen. Voeg bij **Authorized redirect URIs** de callback uit Supabase Authentication > Sign In / Providers > Google toe: `https://<project-ref>.supabase.co/auth/v1/callback`.
2. Schakel in Supabase de Google-provider in en vul de Google Client ID en Client Secret in. Bewaar het secret uitsluitend in Supabase, nooit in de app of Git.
3. Voeg in Supabase Authentication > URL Configuration > Redirect URLs exact `com.circlebeacon.app://login-callback/` toe. Voeg voor web ook de volledige URL van je webapp toe; de app gebruikt de huidige pagina zonder fragment.
4. Zolang het Google consent screen in Testing staat, voeg testgebruikers toe in Google Cloud.
5. Bouw en installeer de app opnieuw: de deep links zitten in de platformconfiguratie.

Controleer op een echt toestel: nieuwe gebruiker, bestaande gebruiker, annuleren bij Google, uitloggen en opnieuw inloggen. Controleer dat gezin/profiel correct worden geladen. De lokale tests vervangen deze OAuth-controle niet. Windows/Linux/macOS hebben nog geen callbackregistratie voor deze flow; de mobiele configuratie betreft Android en iOS.

Documentatie: https://supabase.com/docs/guides/auth/social-login/auth-google en https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter
