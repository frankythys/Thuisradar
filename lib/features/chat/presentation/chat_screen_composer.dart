part of 'chat_screen.dart';

/// Invoerbalk: "+" (foto, locatie), het tekstvak en één ronde knop rechts.
/// Leeg tekstvak = microfoon (spraakbericht), met tekst = verzenden.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onShareLocation,
    required this.onPhoto,
    required this.onVoice,
    required this.recording,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onShareLocation;
  final VoidCallback onPhoto;
  final VoidCallback onVoice;
  final bool recording;

  Future<void> _showExtras(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
              title: const Text('Foto delen'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.primary),
              title: const Text('Mijn locatie delen'),
              onTap: () => Navigator.pop(context, 'location'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'photo') onPhoto();
    if (choice == 'location') onShareLocation();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(tokens.spaceSm, tokens.spaceXs, tokens.spaceSm, tokens.spaceSm),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Foto of locatie delen',
              onPressed: sending || recording ? null : () => _showExtras(context),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.add),
            ),
            SizedBox(width: tokens.spaceXs),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Bericht…'),
              ),
            ),
            SizedBox(width: tokens.spaceXs),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return IconButton.filled(
                  tooltip: hasText
                      ? 'Versturen'
                      : recording
                      ? 'Opname stoppen'
                      : 'Spraakbericht opnemen',
                  onPressed: sending ? null : (hasText ? onSend : onVoice),
                  style: IconButton.styleFrom(
                    backgroundColor: recording ? AppColors.alert : AppColors.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  icon: Icon(
                    hasText
                        ? Icons.send
                        : recording
                        ? Icons.stop
                        : Icons.mic_none,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
