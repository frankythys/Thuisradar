part of 'permissions_screen.dart';

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String note;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              SizedBox(width: tokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    SizedBox(height: tokens.spaceXs),
                    Text(subtitle, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceSm),
              trailing,
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Container(
            padding: EdgeInsets.all(tokens.spaceSm + tokens.spaceXs),
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(note, style: text.bodySmall?.copyWith(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
