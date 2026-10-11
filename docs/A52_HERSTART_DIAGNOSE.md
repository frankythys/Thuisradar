# A52: herstart en onterechte beweging (11 oktober 2026)

## Vastgestelde oorzaak van herstart

Read-only ADB-controles op de A52 tonen native crashes van
`be.thuisradar.thuisradar` om 10:00:32, 11:50:39 en 12:51:35.
Android registreert `APP CRASH(NATIVE)`, status 11. De crashbuffer toont
`SIGSEGV`, null pointer dereference, op `1.raster` in `libflutter.so`.

De lokale enginebibliotheek heeft exact dezelfde Build ID als de crash:
`6d100c35f666e5d3ad663a0e2e1f287817e4ff40`.
Symboliseren met de Android NDK levert onder meer:

- `0x1fd4650`: `impeller::BlitCopyBufferToTextureCommandGLES::Encode`,
  `blit_command_gles.cc:209`.
- `0x1fd500c`: `impeller::EncodeCommandsInReactor`, `blit_pass_gles.cc:67`.
- `0x1fe1f9c`: `impeller::ReactorGLES::FlushOps`, `reactor_gles.cc:385`.

Daarom schakelt de Android-manifest Impeller uit en gebruikt de app Skia.
Dit omzeilt de aangetoonde crashroute. Het is geen wijziging aan batterij-instellingen
of een belofte dat Android nooit een proces kan beëindigen.
Officiële instelling: https://docs.flutter.dev/perf/impeller#android

## Onterechte beweging

Een regressietest voert twaalf identieke posities met nauwkeurigheid 10 m en
GPS-snelheid 1,67 m/s (6 km/u) in. De oude filter rapporteert vanaf de tweede fix
beweging. De aangepaste filter vereist twee metingen én verplaatsing buiten de
gezamenlijke GPS-onzekerheid. Kleine wandelstappen worden vanaf een beginpunt
opgeteld; een aparte test controleert dat echte verplaatsing bevestigd wordt.
Ruwe coördinaten en de upload van aanvaarde metingen blijven behouden.

## Eerste kaartbeeld

De kaart wacht bij de eerste laadbeurt op plaatsen en aanwezigheid, zodat
ruwe losse GPS-markers niet eerst verschijnen en vervolgens op het huis springen.
Bij opnieuw laden met een bestaande waarde blijft de kaart beschikbaar.
Een provider-regressietest controleert beide situaties.

## Controle op de nieuwe telefoonbuild

De aanpassing van de renderer moet in een nieuwe APK zitten; hot reload volstaat niet.
Er is in deze taak geen APK gebouwd of geïnstalleerd. Controleer daarna op de A52:
kaart openen, zoomen, een persoon selecteren, naar het startscherm gaan en de app
heropenen. Zoom en selectie moeten blijven staan; proces-ID en crashbuffer mogen
geen nieuwe native crash tonen. Soepel zoomen en het wegblijven van de native crash
zijn nog niet op de aangepaste telefoonbuild bevestigd.
