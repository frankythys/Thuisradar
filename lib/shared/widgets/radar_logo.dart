import 'package:flutter/material.dart';

/// Het CircleBeacon-beeldmerk: de speld met gezin en beacon-ringen. Hergebruikt
/// in de app-balk, op het loginscherm en in de onboarding.
class RadarLogo extends StatelessWidget {
  const RadarLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'CircleBeacon',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .27),
      child: Image.asset('assets/markers/logo.png', width: size, height: size, fit: BoxFit.cover),
    ),
  );
}
