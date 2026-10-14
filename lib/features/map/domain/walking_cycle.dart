import 'dart:math' as math;

// Wandelcyclus van de sneakers in de ballon: twee identieke schoenen, neus
// naar rechts, die ter plaatse wandelen. Alles is periodiek in de fase
// (0..1), dus de loop sluit wiskundig naadloos.
//
// Maten zijn fracties van het vak (breedte B, hoogte H), zodat de tekening
// op elke grootte gelijk blijft.

/// Duur van één volledige cyclus (beide voeten één pas).
const kWalkCycleMs = 1600;

/// Beelden per seconde waarmee de cyclus naar afbeeldingen wordt omgezet.
const kWalkFps = 30;

/// Zoveel beelden vormen samen één naadloze loop.
const kWalkingLoopFrames = kWalkCycleMs * kWalkFps ~/ 1000;

/// Hoe lang elk beeld blijft staan; samen precies [kWalkCycleMs].
const kWalkFrameDuration = Duration(microseconds: kWalkCycleMs * 1000 ~/ kWalkingLoopFrames);

/// Deel van de cyclus dat een voet op de grond staat.
const kStance = 0.6;

/// Schoenlengte t.o.v. B.
const kShoeLength = 0.40;

/// Afstand die een voet per cyclus heen en terug aflegt, t.o.v. B.
const kStride = 0.38;

/// Hoogste optilling tijdens de zwaai, t.o.v. H.
const kLift = 0.11;

/// Grondlijn t.o.v. H (van boven).
const kGround = 0.84;

/// Laatste stuk van de steunfase waarin de hiel loskomt.
const kHeelOff = 0.15;

/// Kanteling bij het afzetten (neus omlaag), in graden, rechtsom positief.
const kToeOffDegrees = 16.0;

/// Kanteling vlak voor het landen (neus omhoog).
const kHeelStrikeDegrees = -9.0;

/// De achterste voet staat iets hoger (diepte), t.o.v. H.
const kFarRaise = 0.02;

/// De achterste voet is iets donkerder (diepte): factor op de kleur.
const kFarShade = 0.86;

/// Houding van één schoen: [x] t.o.v. het midden (fractie van B), [lift]
/// 0..1 (maal [kLift]), [pitchDegrees] rechtsom positief (neus omlaag).
typedef SneakerPose = ({double x, double lift, double pitchDegrees});

/// Zachte overgang 0..1 (begint en eindigt zonder schok).
double smoothStep(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Houding van een schoen op [phase] (elke waarde; enkel het deel na de
/// komma telt). Steunfase: op de grond, schuift gelijkmatig naar achter, op
/// het einde komt de hiel los. Zwaaifase: omhoog, naar voren, landen op de hiel.
SneakerPose sneakerPose(double phase) {
  final p0 = phase - phase.floorToDouble();
  if (p0 < kStance) {
    final p = p0 / kStance;
    const heelPart = kHeelOff / kStance;
    final h = (p - (1 - heelPart)) / heelPart;
    return (
      x: kStride / 2 - kStride * p,
      lift: 0.0,
      pitchDegrees: h > 0 ? kToeOffDegrees * smoothStep(h) : 0.0,
    );
  }
  final q = (p0 - kStance) / (1 - kStance);
  final double pitch;
  if (q < 0.4) {
    pitch = _lerp(kToeOffDegrees, 0, smoothStep(q / 0.4));
  } else if (q < 0.8) {
    pitch = _lerp(0, kHeelStrikeDegrees, smoothStep((q - 0.4) / 0.4));
  } else {
    pitch = _lerp(kHeelStrikeDegrees, 0, smoothStep((q - 0.8) / 0.2));
  }
  return (x: -kStride / 2 + kStride * smoothStep(q), lift: math.sin(math.pi * q), pitchDegrees: pitch);
}

/// Hoe ver het laagste punt van de zool onder het midden van de schoen ligt,
/// na kantelen over [pitchDegrees], voor een schoen van [width] × [height].
/// Zo rust de schoen altijd op hiel of neus, nooit door de grond.
double sneakerBottom(double pitchDegrees, double width, double height) {
  final rad = pitchDegrees * math.pi / 180;
  final s = math.sin(rad);
  final c = math.cos(rad);
  // Onderkant hiel en voorvoet (de neus staat iets omhoog), t.o.v. het midden.
  final heel = -width * 0.47 * s + height * 0.5 * c;
  final toe = width * 0.47 * s + height * 0.42 * c;
  return math.max(heel, toe);
}
