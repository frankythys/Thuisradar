part of 'family_setup_screen.dart';

/// Keuzetegel: wit met rand, of zacht Oceaan-blauw met dikke rand als gekozen.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radiusCard);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm, vertical: tokens.spaceMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 26),
                ),
                SizedBox(height: tokens.spaceSm),
                Text(label, style: text.titleMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
