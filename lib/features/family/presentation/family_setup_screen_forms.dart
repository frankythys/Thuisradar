part of 'family_setup_screen.dart';

class _CreateForm extends StatelessWidget {
  const _CreateForm({required this.controller, required this.busy, required this.onSubmit});

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel(label: 'Familienaam'),
        SizedBox(height: tokens.spaceSm),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            hintText: 'Familie Thys',
            fillColor: AppColors.surfaceLow,
            prefixIcon: Icon(Icons.groups_outlined, color: AppColors.primary),
          ),
        ),
        SizedBox(height: tokens.spaceMd),
        FilledButton.icon(
          onPressed: busy ? null : onSubmit,
          icon: const Icon(Icons.arrow_forward, size: 20),
          iconAlignment: IconAlignment.end,
          label: const Text('Familie aanmaken'),
        ),
      ],
    );
  }
}

class _JoinForm extends StatelessWidget {
  const _JoinForm({
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onPaste,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _FieldLabel(label: 'Uitnodigingscode')),
            TextButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Plakken'),
            ),
          ],
        ),
        SizedBox(height: tokens.spaceXs),
        InviteCodeInput(controller: controller),
        SizedBox(height: tokens.spaceMd),
        FilledButton.icon(
          onPressed: busy ? null : onSubmit,
          icon: const Icon(Icons.group_add_outlined, size: 20),
          label: const Text('Deelnemen aan familie'),
        ),
      ],
    );
  }
}
