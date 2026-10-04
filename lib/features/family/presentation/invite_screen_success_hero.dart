part of 'invite_screen.dart';

class _SuccessHero extends StatelessWidget {
  const _SuccessHero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          size: 42,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
