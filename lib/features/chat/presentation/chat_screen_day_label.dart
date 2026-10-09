part of 'chat_screen.dart';

/// "Vandaag" / "Gisteren" / "ma 6/10" als klein pilletje tussen de berichten.
class _DayLabel extends StatelessWidget {
  const _DayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: tokens.spaceSm),
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm + tokens.spaceXs, vertical: tokens.spaceXs),
        decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.muted)),
      ),
    );
  }
}
