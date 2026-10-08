part of 'login_screen.dart';

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.trailingLabel,
    this.helper,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffix,
    this.validator,
  });

  final String label;
  final String? trailingLabel;
  final String? helper;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: text.titleMedium),
            const Spacer(),
            if (trailingLabel != null)
              Text(trailingLabel!, style: text.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            fillColor: Theme.of(context).scaffoldBackgroundColor == AppColors.ground
                ? AppColors.surfaceLow
                : Colors.white,
            prefixIcon: Icon(icon, color: AppColors.primary),
            suffixIcon: suffix,
          ),
        ),
        if (helper != null) ...[
          SizedBox(height: tokens.spaceXs),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
              SizedBox(width: tokens.spaceXs),
              Text(helper!, style: text.bodySmall?.copyWith(color: AppColors.muted)),
            ],
          ),
        ],
      ],
    );
  }
}
