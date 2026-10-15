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
        _FieldLabel(label: context.l10n.familyNameLabel),
        SizedBox(height: tokens.spaceSm),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: context.l10n.familyNameHint,
            fillColor: AppColors.surfaceLow,
            prefixIcon: const Icon(Icons.groups_outlined, color: AppColors.primary),
          ),
        ),
        SizedBox(height: tokens.spaceMd),
        FilledButton.icon(
          onPressed: busy ? null : onSubmit,
          icon: const Icon(Icons.arrow_forward, size: 20),
          iconAlignment: IconAlignment.end,
          label: Text(context.l10n.familyCreate),
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
            Expanded(child: _FieldLabel(label: context.l10n.familyInviteCodeField)),
            TextButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste, size: 18),
              label: Text(context.l10n.familyPaste),
            ),
          ],
        ),
        SizedBox(height: tokens.spaceXs),
        InviteCodeInput(controller: controller),
        SizedBox(height: tokens.spaceMd),
        FilledButton.icon(
          onPressed: busy ? null : onSubmit,
          icon: const Icon(Icons.group_add_outlined, size: 20),
          label: Text(context.l10n.familyJoin),
        ),
      ],
    );
  }
}
