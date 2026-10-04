part of 'map_screen.dart';

class _OwnSosBanner extends StatelessWidget {
  const _OwnSosBanner({required this.onResolve});

  final Future<void> Function() onResolve;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: AppColors.alert,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.shield, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SOS actief · je gezin is gewaarschuwd',
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: onResolve,
              child: const Text(
                'Oplossen',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
