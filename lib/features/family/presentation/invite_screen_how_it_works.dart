part of 'invite_screen.dart';

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final steps = [
      context.l10n.familyStepInstall,
      context.l10n.familyStepChoose,
      context.l10n.familyStepEnter,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.familyHowItWorks, style: text.titleSmall),
          SizedBox(height: tokens.spaceSm),
          for (final (index, step) in steps.indexed) ...[
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
