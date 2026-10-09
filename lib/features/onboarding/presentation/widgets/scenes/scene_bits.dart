import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Vaste tekenmaat van elke scène; de stage schaalt die naar het scherm.
const sceneSize = Size(280, 260);

/// Breedte gedeeld door hoogte van [sceneSize].
const sceneAspectRatio = 280 / 260;

/// Voortgang van een deel van de animatie: 0 vóór [start], 1 na [end].
double phase(double t, double start, double end, [Curve curve = Curves.easeOutCubic]) =>
    curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

/// Basis voor een scène die op een animatiewaarde 0..1 tekent.
abstract class AnimatedScene extends AnimatedWidget {
  const AnimatedScene({super.key, required Animation<double> progress}) : super(listenable: progress);

  double get t => (listenable as Animation<double>).value;
}

/// Zachte schaduw voor zwevende elementen in een scène.
const sceneShadow = [
  BoxShadow(color: Color(0x2E0F1E24), blurRadius: 18, spreadRadius: -8, offset: Offset(0, 8)),
];

/// Plaatst [child] met zijn middelpunt op ([x], [y]) binnen [sceneSize].
class SceneDot extends StatelessWidget {
  const SceneDot({super.key, required this.x, required this.y, required this.size, required this.child});

  final double x;
  final double y;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Positioned(left: x - size / 2, top: y - size / 2, width: size, height: size, child: child);
}

/// Rond gezinslid-avatar met witte rand en optioneel online-stipje.
class SceneAvatar extends StatelessWidget {
  const SceneAvatar({super.key, required this.letter, required this.color, this.online = false});

  final String letter;
  final Color color;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: sceneShadow,
            ),
            child: Center(
              child: Text(
                letter,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        if (online)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF2FB37A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Witte pil met icoon en kort label.
class ScenePill extends StatelessWidget {
  const ScenePill({super.key, required this.icon, required this.label, this.muted = false});

  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.muted : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder(), shadows: sceneShadow),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: muted ? AppColors.muted : AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Afgerond vierkant icoon-tegeltje (plaats of app-icoon in een melding).
class SceneTile extends StatelessWidget {
  const SceneTile({super.key, required this.icon, required this.color, required this.background});

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 18, color: color),
  );
}
