part of 'login_screen.dart';

/// "Onthouden" en "Wachtwoord vergeten?" op één regel.
class _RememberRow extends StatelessWidget {
  const _RememberRow({required this.value, required this.onChanged, required this.onForgot});

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onForgot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.tokens.spaceXs),
      child: Row(
        children: [
          Tooltip(
            message: context.l10n.authRememberTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(context.tokens.radiusSm),
              onTap: onChanged == null ? null : () => onChanged!(!value),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(value: value, onChanged: onChanged),
                  Text(context.l10n.authRemember),
                ],
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgot,
                child: Text(context.l10n.authForgotPassword, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoofdknop over de volledige formulierbreedte.
class _LoginActions extends StatelessWidget {
  const _LoginActions({required this.label, required this.busy, required this.onSubmit});

  final String label;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onSubmit,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                SizedBox(width: context.tokens.spaceSm),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton.filledTonal(
        tooltip: context.l10n.authBiometricButton,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(56),
          backgroundColor: AppColors.primarySoft,
          foregroundColor: AppColors.primary,
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.fingerprint, size: 30),
      ),
    );
  }
}
