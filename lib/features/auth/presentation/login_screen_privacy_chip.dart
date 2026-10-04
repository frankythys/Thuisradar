part of 'login_screen.dart';

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'PRIVACY EERST',
              style: text.labelSmall?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
