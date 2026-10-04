part of 'family_setup_screen.dart';

class _StepPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const ShapeDecoration(
        color: AppColors.primarySoft,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Stap 2 van 3',
            style: text.labelMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
