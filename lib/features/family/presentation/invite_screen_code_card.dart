part of 'invite_screen.dart';

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: tokens.spaceSm),
              Text('Jouw unieke gezinscode', style: text.titleMedium),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: tokens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Text(
              code.split('').join(' '),
              style: text.headlineLarge?.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Text('Alleen voor jouw gezin', style: text.bodySmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
