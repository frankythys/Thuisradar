part of 'chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceSm),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Deel je locatie',
              onPressed: onShareLocation,
              icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Bericht voor de familie…',
                  suffixIcon: IconButton(
                    tooltip: 'Foto toevoegen',
                    onPressed: sending || recording ? null : onPhoto,
                    icon: const Icon(Icons.attach_file),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: recording ? 'Opname stoppen' : 'Spraakbericht opnemen',
              onPressed: sending ? null : onVoice,
              icon: Icon(
                recording ? Icons.stop_circle : Icons.mic_none,
                color: recording ? AppColors.alert : AppColors.primary,
              ),
            ),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
