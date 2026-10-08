# Gratis wegcorrectie voor autoritten

De kaart gebruikt lokale, lichte map-matching op recente GPS-punten. Afstand tot
de weg, bewegingsrichting, eenrichtingsverkeer, aansluitingen en eerdere punten
helpen een geschikte weg kiezen. Bij meerdere ongeveer even waarschijnlijke
wegen blijft de oorspronkelijke GPS-positie zichtbaar. Dit is geen volledige
routeringsengine en geeft geen garantie op rijstrookniveau.

De bestaande MotionFilter blijft actief. Matching begint na minimaal drie
recente bewegende metingen, met nauwkeurigheid tot 50 meter en minstens één
snelheid van 5 m/s. Stops, verouderde metingen en ontbrekende wegen gebruiken
de bestaande weergave. Alleen kaartcoördinaten worden aangepast; opgeslagen
GPS-metingen, ritgeschiedenis en geofence-berekeningen blijven origineel.
Rijdende markers staan met hun midden op het kaartpunt, worden niet geclusterd
en worden niet door een oude aanwezigheid op Thuis verplaatst.

Wegen komen uit OpenStreetMap via de publieke Overpass-server. Er is geen
API-sleutel, abonnement of betaalde fallback. Alleen een grof gebiedsvak wordt
opgevraagd, zonder gebruikers-ID of GPS-ritpunten. De server ziet wel het
opgevraagde gebied en het IP-adres. Wegdata worden lokaal bewaard: maximaal
16 gebieden, met een geldigheid van 30 dagen op schijf.

Per toestel gelden maximaal 12 verzoeken en een budget van 6 MB per dag, met
minimaal één minuut tussen verzoeken. Eén antwoord mag maximaal 2 MB zijn;
het dagbudget kan daardoor bij het laatste antwoord worden overschreden.
Bij een limiet, netwerkprobleem of serverfout blijft GPS werken; gecachte
gebieden blijven bruikbaar. Dit beperkt bij lange ritten de beschikbare
wegcorrectie tot gebieden die al geladen zijn.

De publieke server is bedoeld voor beperkt persoonlijk gebruik, zonder
beschikbaarheidsbelofte. De limieten per toestel zijn geen garantie dat een
grote gebruikersgroep binnen de gedeelde servercapaciteit blijft. Voor brede
distributie is een eigen wegdatavoorziening nodig; de app activeert nooit
automatisch een betaalde dienst.

Bron: https://dev.overpass-api.de/overpass-doc/en/preface/commons.html
