part of 'invite_screen.dart';

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Laat hen de Thuisradar app installeren.',
    'Kies "Ik heb een uitnodigingscode" en vul bovenstaande code in.',
    'Jullie zien elkaar direct veilig op de kaart.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hoe werkt het voor gezinsleden?', style: text.titleLarge),
          SizedBox(height: tokens.spaceMd),
          for (final (index, step) in _steps.indexed) ...[
            if (index > 0) SizedBox(height: tokens.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
