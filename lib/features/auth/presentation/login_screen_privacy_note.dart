part of 'login_screen.dart';

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.primary),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.authInviteOnly, style: text.titleMedium),
                SizedBox(height: tokens.spaceXs),
                Text(
                  context.l10n.authInviteOnlyText,
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
