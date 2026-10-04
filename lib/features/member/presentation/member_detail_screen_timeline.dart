part of 'member_detail_screen.dart';

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Geen geschiedenis',
        message: 'Voor deze dag is er nog geen locatiegeschiedenis.',
      );
    }

    // Nieuwste bovenaan.
    final ordered = entries.reversed.toList();
    return AppCard(
      child: Column(
        children: [
          for (final (index, entry) in ordered.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _TimelineRow(entry: entry),
          ],
        ],
      ),
    );
  }
}
