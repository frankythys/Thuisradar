import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/chat_providers.dart';
import '../domain/attachment.dart';

final attachmentUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(chatRepositoryProvider).attachmentUrl(path),
);

class AttachmentView extends ConsumerStatefulWidget {
  const AttachmentView({super.key, required this.attachment});
  final Attachment attachment;
  @override
  ConsumerState<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends ConsumerState<AttachmentView> {
  final _player = AudioPlayer();
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(attachmentUrlProvider(widget.attachment.path))
      .when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(attachmentUrlProvider(widget.attachment.path)),
          child: const Text('Bijlage opnieuw laden'),
        ),
        data: (url) => widget.attachment.kind == 'image'
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Text('Foto niet beschikbaar'),
                ),
              )
            : TextButton.icon(
                onPressed: () async {
                  try {
                    if (_playing) {
                      await _player.pause();
                    } else {
                      await _player.play(UrlSource(url));
                    }
                    if (mounted) setState(() => _playing = !_playing);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Afspelen mislukt. Probeer opnieuw.')));
                    }
                  }
                },
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                label: const Text('Spraakbericht'),
              ),
      );
}
