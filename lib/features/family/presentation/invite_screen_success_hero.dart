part of 'invite_screen.dart';

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({required this.justCreated});

  final bool justCreated;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
        child: Icon(justCreated ? Icons.check_circle : Icons.group_add, size: 32, color: AppColors.primary),
      ),
    );
  }
}
