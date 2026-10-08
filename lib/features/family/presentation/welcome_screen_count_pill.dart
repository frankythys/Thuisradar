part of 'welcome_screen.dart';

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const ShapeDecoration(color: AppColors.primarySoft, shape: StadiumBorder()),
      child: Text(
        '$count ${count == 1 ? 'lid' : 'leden'}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
