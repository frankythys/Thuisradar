part of 'family_setup_screen.dart';

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const ShapeDecoration(
        color: AppColors.primarySoft,
        shape: StadiumBorder(),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
