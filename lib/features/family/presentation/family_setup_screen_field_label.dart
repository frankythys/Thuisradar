part of 'family_setup_screen.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: Theme.of(context).textTheme.titleMedium);
}
