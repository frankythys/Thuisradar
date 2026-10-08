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
            message: 'E-mailadres en wachtwoord versleuteld bewaren op dit toestel',
            child: InkWell(
              borderRadius: BorderRadius.circular(context.tokens.radiusSm),
              onTap: onChanged == null ? null : () => onChanged!(!value),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(value: value, onChanged: onChanged),
                  const Text('Onthouden'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgot,
                child: const Text('Wachtwoord vergeten?', overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoofdknop met, bij inloggen, een ronde vingerafdrukknop ernaast.
class _LoginActions extends StatelessWidget {
  const _LoginActions({required this.label, required this.busy, required this.onSubmit, this.onBiometric});

  final String label;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
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
                      SizedBox(width: tokens.spaceSm),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
        if (onBiometric != null) ...[
          SizedBox(width: tokens.spaceSm + tokens.spaceXs),
          IconButton.filledTonal(
            tooltip: 'Inloggen met biometrie',
            style: IconButton.styleFrom(
              fixedSize: const Size.square(52),
              backgroundColor: AppColors.primarySoft,
              foregroundColor: AppColors.primary,
            ),
            onPressed: busy ? null : onBiometric,
            icon: const Icon(Icons.fingerprint, size: 26),
          ),
        ],
      ],
    );
  }
}
