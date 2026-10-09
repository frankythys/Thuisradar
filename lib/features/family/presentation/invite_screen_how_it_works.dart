part of 'invite_screen.dart';

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Installeer CircleBeacon',
    'Kies "Ik heb een uitnodigingscode"',
    'Vul de code in, klaar',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zo werkt het', style: text.titleSmall),
          SizedBox(height: tokens.spaceSm),
          for (final (index, step) in _steps.indexed) ...[
            if (index > 0) SizedBox(height: tokens.spaceSm),
            Row(
              children: [
                _StepBadge(number: index + 1),
                SizedBox(width: tokens.spaceMd),
                Expanded(child: Text(step, style: text.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
