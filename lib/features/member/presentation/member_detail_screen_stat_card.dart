part of 'member_detail_screen.dart';

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          SizedBox(height: tokens.spaceSm),
          Text(value, style: text.titleLarge),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
