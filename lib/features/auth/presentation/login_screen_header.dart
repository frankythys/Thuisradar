part of 'login_screen.dart';

/// Logo + appnaam bovenaan; bij registreren met terugpijl en privacy-chip.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        if (onBack != null)
          IconButton(tooltip: 'Terug', onPressed: onBack, icon: const Icon(Icons.arrow_back))
        else ...[
          const RadarLogo(size: 44),
          SizedBox(width: tokens.spaceSm + tokens.spaceXs),
          Text('CircleBeacon', style: Theme.of(context).textTheme.titleLarge),
        ],
        const Spacer(),
        if (onBack != null) const _PrivacyChip(),
      ],
    );
  }
}
