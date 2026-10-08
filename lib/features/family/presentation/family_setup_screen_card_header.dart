part of 'family_setup_screen.dart';

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.body,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String body;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(tokens.radiusInput),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: text.titleLarge)),
                  if (badge != null) _Badge(label: badge!),
                ],
              ),
              SizedBox(height: tokens.spaceXs),
              Text(body, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
