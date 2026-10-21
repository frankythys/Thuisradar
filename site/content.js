// Teksten van de publieke pagina's (Nederlands en Engels). Houd dit gelijk
// met wat de app echt doet: Google Play vergelijkt het privacybeleid met de
// app en met het Data safety-formulier.

export const UPDATED = '21 oktober 2026';
export const UPDATED_EN = '21 October 2026';

export const TEXT = {
  nl: {
    lang: 'nl',
    other: { lang: 'en', label: 'English' },
    home: {
      title: 'CircleBeacon',
      intro: 'CircleBeacon is een app om je locatie te delen met je eigen gezin: een live kaart, plaatsen met aankomst- en vertrekmeldingen, een familiechat en een SOS-knop.',
      links: [['Privacybeleid', '/privacy'], ['Account verwijderen', '/account/delete']],
    },
    privacy: {
      title: 'Privacybeleid',
      updated: `Laatst bijgewerkt: ${UPDATED}`,
      sections: [
        ['Wie we zijn', '<p>CircleBeacon (in de code “Thuisradar”) is een kleine, onafhankelijke app van {OWNER} uit België. Vragen over je gegevens stuur je naar <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>'],
        ['Kort samengevat', '<p>Je deelt je locatie enkel met de mensen in je eigen gezin. We tonen geen advertenties, gebruiken geen analyse- of trackingdiensten en verkopen geen gegevens. Locatiegeschiedenis bewaren we hoogstens 31 dagen. Je kan je account en al je gegevens altijd zelf verwijderen.</p>'],
        ['Welke gegevens', `<ul>
<li><strong>Account:</strong> je e-mailadres en wachtwoord (versleuteld bewaard door Supabase Auth), of je Google-account als je met Google aanmeldt; je naam en een kleur voor op de kaart; optioneel je telefoonnummer.</li>
<li><strong>Locatie:</strong> je precieze locatie, ook als de app gesloten is of niet gebruikt wordt, met nauwkeurigheid, snelheid, batterijniveau en tijdstip. Zo zien je gezinsleden waar je bent, krijgen ze meldingen bij aankomst en vertrek, en zie je je ritten en geschiedenis. Je kan het delen altijd pauzeren in Profiel; zolang het loopt, staat er een vaste melding.</li>
<li><strong>Beweging:</strong> als je het toestaat, je aantal stappen en of je wandelt, fietst of rijdt (activiteitsherkenning van je toestel), om ritten juist te tonen.</li>
<li><strong>Plaatsen en parkeerplek:</strong> de plaatsen die je gezin aanmaakt (naam, plek, straal), wie er aanwezig is, en een gedeelde parkeerplek.</li>
<li><strong>Chat:</strong> berichten, foto's en spraakberichten die je in de familiechat stuurt.</li>
<li><strong>SOS en noodcontacten:</strong> je SOS-meldingen met locatie, en de naam en het telefoonnummer van je noodcontacten. Bij een SOS opent de app je berichten-app met een sms klaar; jij verstuurt die zelf.</li>
<li><strong>Toestel:</strong> een pushtoken (Firebase Cloud Messaging) om meldingen te sturen, en een toestelsleutel voor de zonebewaking.</li>
</ul>`],
        ['Wie je gegevens ziet', '<p>Enkel de leden van je gezin: wie je uitnodigt met een code. De beveiliging zit in de database zelf (row level security): een ander gezin kan je gegevens niet opvragen. Wie het gezin verlaat of verwijderd wordt, neemt zijn locatie en geschiedenis mee.</p>'],
        ['Dienstverleners', `<ul>
<li><strong>Supabase</strong>: database, opslag van bijlagen en aanmelden. Alle gegevens hierboven staan daar.</li>
<li><strong>Google</strong>: Firebase Cloud Messaging voor meldingen, aanmelden met Google (als je dat kiest), en het omzetten van coördinaten naar een adres via de geocoder van je toestel.</li>
<li><strong>OpenStreetMap</strong> (kaarttegels) en <strong>Overpass API</strong> (wegen bij een rit): krijgen het kaartgebied dat je bekijkt, niet wie je bent. Als de app Google Maps gebruikt, laadt Google de kaart.</li>
<li><strong>Cloudflare</strong>: host deze website.</li>
</ul><p>Sommige van deze diensten verwerken gegevens buiten de Europese Economische Ruimte, onder de waarborgen die zij daarvoor bieden (zoals de standaardcontractbepalingen van de EU). De verbinding is altijd versleuteld (HTTPS).</p>`],
        ['Hoe lang we bewaren', `<ul>
<li>Locatiegeschiedenis: 31 dagen, daarna wist de server ze automatisch elke nacht.</li>
<li>Je laatste locatie, plaatsen, chat, SOS-meldingen en noodcontacten: zolang je account en je gezin bestaan.</li>
<li>Verwijder je je account, dan wissen we alles meteen. Ben je de laatste in je gezin, dan verdwijnt ook het gezin met zijn plaatsen en chat.</li>
</ul>`],
        ['Waarom we dit mogen', '<p>We verwerken je gegevens om de dienst te leveren waar je om vraagt (uitvoering van de overeenkomst), en je locatie op de achtergrond, beweging en meldingen enkel met je toestemming, die je altijd kan intrekken in de instellingen van je toestel of door het delen te pauzeren.</p>'],
        ['Je rechten', '<p>Je kan je gegevens inzien, laten verbeteren, laten wissen, overdragen of bezwaar maken. Je account verwijderen kan in de app (Profiel → Account verwijderen) of via <a href="/account/delete">deze pagina</a>. Ben je niet tevreden, dan kan je klacht indienen bij de Gegevensbeschermingsautoriteit (<a href="https://www.gegevensbeschermingsautoriteit.be">gegevensbeschermingsautoriteit.be</a>).</p>'],
        ['Leeftijd', '<p>Je moet minstens 13 jaar zijn om zelf een account te maken.</p>'],
        ['Wijzigingen', '<p>Passen we dit beleid aan, dan zie je de nieuwe datum bovenaan. Grote wijzigingen melden we in de app.</p>'],
      ],
    },
    del: {
      title: 'Account verwijderen',
      intro: 'Hier verwijder je je CircleBeacon-account met al je gegevens: je profiel, je locaties en geschiedenis, berichten en bijlagen, SOS-meldingen en noodcontacten. Ben je de laatste in je gezin, dan verdwijnt ook het gezin met zijn plaatsen en chat. Dit kan je niet ongedaan maken.',
      inApp: 'Het snelst gaat het in de app: <strong>Profiel → Account verwijderen</strong>.',
      email: 'E-mailadres',
      password: 'Wachtwoord',
      submit: 'Account definitief verwijderen',
      google: 'Meld je aan met Google en heb je geen wachtwoord? Verwijder je account dan in de app, of stuur vanaf je e-mailadres een mail naar <a href="mailto:{EMAIL}?subject=Account%20verwijderen">{EMAIL}</a> met als onderwerp “Account verwijderen”. We verwijderen het dan binnen 30 dagen en laten het je weten.',
      done: 'Je account en al je gegevens zijn verwijderd.',
      badLogin: 'Dat e-mailadres of wachtwoord klopt niet.',
      owner: 'Je bent beheerder van een gezin waar nog anderen in zitten. Maak in de app eerst iemand anders beheerder (Profiel → je gezin); daarna kan je je account verwijderen.',
      failed: 'Dat lukte niet. Probeer het later opnieuw, of stuur ons een mail.',
      missing: 'Vul je e-mailadres en wachtwoord in.',
    },
    confirmed: {
      title: 'E-mailadres bevestigd',
      body: 'Je e-mailadres is bevestigd. Open CircleBeacon op je gsm en log in met je e-mailadres en wachtwoord.',
      errorTitle: 'Link werkt niet meer',
      error: 'Deze bevestigingslink is verlopen of al gebruikt. Probeer in de app in te loggen; lukt dat niet, registreer dan opnieuw om een nieuwe mail te krijgen.',
    },
    footer: 'CircleBeacon',
  },
  en: {
    lang: 'en',
    other: { lang: 'nl', label: 'Nederlands' },
    home: {
      title: 'CircleBeacon',
      intro: 'CircleBeacon is an app to share your location with your own family: a live map, places with arrival and departure alerts, a family chat and an SOS button.',
      links: [['Privacy policy', '/privacy'], ['Delete account', '/account/delete']],
    },
    privacy: {
      title: 'Privacy policy',
      updated: `Last updated: ${UPDATED_EN}`,
      sections: [
        ['Who we are', '<p>CircleBeacon (“Thuisradar” in the code) is a small, independent app by {OWNER} from Belgium. Questions about your data: <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>'],
        ['In short', '<p>You share your location only with the people in your own family. We show no ads, use no analytics or tracking services and sell no data. We keep location history for at most 31 days. You can delete your account and all your data yourself at any time.</p>'],
        ['What data', `<ul>
<li><strong>Account:</strong> your email address and password (stored hashed by Supabase Auth), or your Google account if you sign in with Google; your name and a colour for the map; optionally your phone number.</li>
<li><strong>Location:</strong> your precise location, also when the app is closed or not in use, with accuracy, speed, battery level and time. This lets your family see where you are, get arrival and departure alerts, and lets you see your trips and history. You can pause sharing anytime in Profile; while it runs, a persistent notification is shown.</li>
<li><strong>Motion:</strong> if you allow it, your step count and whether you walk, cycle or drive (your device's activity recognition), to show trips correctly.</li>
<li><strong>Places and parking spot:</strong> the places your family creates (name, position, radius), who is present, and a shared parking spot.</li>
<li><strong>Chat:</strong> messages, photos and voice messages you send in the family chat.</li>
<li><strong>SOS and emergency contacts:</strong> your SOS alerts with location, and the name and phone number of your emergency contacts. On SOS the app opens your messaging app with a text ready; you send it yourself.</li>
<li><strong>Device:</strong> a push token (Firebase Cloud Messaging) to send notifications, and a device key for place monitoring.</li>
</ul>`],
        ['Who sees your data', '<p>Only the members of your family: the people you invite with a code. Access control lives in the database itself (row level security): another family cannot read your data. Whoever leaves or is removed from the family takes their location and history with them.</p>'],
        ['Service providers', `<ul>
<li><strong>Supabase</strong>: database, attachment storage and sign-in. All data above is stored there.</li>
<li><strong>Google</strong>: Firebase Cloud Messaging for notifications, Google sign-in (if you choose it), and turning coordinates into an address via your device's geocoder.</li>
<li><strong>OpenStreetMap</strong> (map tiles) and <strong>Overpass API</strong> (roads for a trip): receive the map area you view, not who you are. If the app uses Google Maps, Google loads the map.</li>
<li><strong>Cloudflare</strong>: hosts this website.</li>
</ul><p>Some of these services process data outside the European Economic Area, under the safeguards they provide (such as the EU standard contractual clauses). The connection is always encrypted (HTTPS).</p>`],
        ['How long we keep it', `<ul>
<li>Location history: 31 days; the server deletes older history automatically every night.</li>
<li>Your latest location, places, chat, SOS alerts and emergency contacts: as long as your account and your family exist.</li>
<li>If you delete your account, we erase everything immediately. If you are the last one in your family, the family with its places and chat is deleted too.</li>
</ul>`],
        ['Legal basis', '<p>We process your data to provide the service you ask for (performance of a contract), and background location, motion and notifications only with your consent, which you can withdraw anytime in your device settings or by pausing sharing.</p>'],
        ['Your rights', '<p>You can access, correct, delete or port your data, or object to processing. Delete your account in the app (Profile → Delete account) or via <a href="/account/delete?lang=en">this page</a>. If you are not satisfied, you can file a complaint with the Belgian Data Protection Authority (<a href="https://www.dataprotectionauthority.be">dataprotectionauthority.be</a>).</p>'],
        ['Age', '<p>You must be at least 13 years old to create an account yourself.</p>'],
        ['Changes', '<p>If we change this policy, you will see the new date at the top. We announce major changes in the app.</p>'],
      ],
    },
    del: {
      title: 'Delete account',
      intro: 'Here you delete your CircleBeacon account with all your data: your profile, your locations and history, messages and attachments, SOS alerts and emergency contacts. If you are the last one in your family, the family with its places and chat is deleted too. This cannot be undone.',
      inApp: 'The quickest way is in the app: <strong>Profile → Delete account</strong>.',
      email: 'Email address',
      password: 'Password',
      submit: 'Delete account permanently',
      google: 'Signed in with Google and have no password? Delete your account in the app, or email <a href="mailto:{EMAIL}?subject=Delete%20account">{EMAIL}</a> from your account address with the subject “Delete account”. We delete it within 30 days and let you know.',
      done: 'Your account and all your data have been deleted.',
      badLogin: 'That email address or password is not correct.',
      owner: 'You are the admin of a family that still has other members. First make someone else admin in the app (Profile → your family); then you can delete your account.',
      failed: 'That did not work. Please try again later, or email us.',
      missing: 'Fill in your email address and password.',
    },
    confirmed: {
      title: 'Email address confirmed',
      body: 'Your email address is confirmed. Open CircleBeacon on your phone and sign in with your email address and password.',
      errorTitle: 'Link no longer works',
      error: 'This confirmation link has expired or was already used. Try signing in in the app; if that fails, sign up again to get a new email.',
    },
    footer: 'CircleBeacon',
  },
};
