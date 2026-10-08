part of 'permissions_screen.dart';

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const ShapeDecoration(color: AppColors.primarySoft, shape: StadiumBorder()),
      child: Text(
        'VEREIST',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
