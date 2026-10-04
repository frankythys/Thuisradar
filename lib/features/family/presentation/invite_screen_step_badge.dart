part of 'invite_screen.dart';

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
