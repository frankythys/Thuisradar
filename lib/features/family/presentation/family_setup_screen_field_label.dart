part of 'family_setup_screen.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(label, style: text.titleMedium),
        const Spacer(),
        if (trailing != null) Text(trailing!, style: text.bodySmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }
}
