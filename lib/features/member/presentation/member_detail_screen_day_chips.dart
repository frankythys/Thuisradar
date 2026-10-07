part of 'member_detail_screen.dart';

class _DayChips extends StatelessWidget {
  const _DayChips({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Wrap(
      runSpacing: 8,
      children: [
        for (final (index, label) in _MemberDetailScreenState._dayLabels.indexed)
          Padding(
            padding: EdgeInsets.only(right: tokens.spaceSm),
            child: Material(
              color: index == selected ? AppColors.primary : Colors.white,
              shape: const StadiumBorder(),
              child: InkWell(
                onTap: () => onSelected(index),
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text(
                    label,
                    style: text.labelLarge?.copyWith(color: index == selected ? Colors.white : AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
