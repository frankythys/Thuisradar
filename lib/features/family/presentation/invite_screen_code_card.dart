part of 'invite_screen.dart';

/// De gezinscode groot in beeld, met het kopieer-icoon er meteen naast.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        children: [
          Text('JULLIE GEZINSCODE', style: text.labelSmall?.copyWith(color: AppColors.muted)),
          SizedBox(height: tokens.spaceSm),
          Container(
            padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceXs, tokens.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      code.split('').join(' '),
                      style: text.headlineLarge?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Code kopiëren',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
