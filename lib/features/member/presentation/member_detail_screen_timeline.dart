part of 'member_detail_screen.dart';

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, this.onSaveAsPlace});

  final List<TimelineEntry> entries;

  /// Een stop zonder plaatsnaam (bv. je werk) een naam geven.
  final ValueChanged<TimelineEntry>? onSaveAsPlace;

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
            _TimelineRow(
              entry: entry,
              onSaveAsPlace: onSaveAsPlace == null ? null : () => onSaveAsPlace!(entry),
            ),
          ],
        ],
      ),
    );
  }
}
