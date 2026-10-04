import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/widgets/contact_actions.dart';
import '../domain/attachment.dart';
import 'attachment_view.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../../shared/widgets/location_preview.dart';
import '../../location/application/location_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../application/chat_providers.dart';
import '../domain/message.dart';

part 'chat_screen_bubble.dart';
part 'chat_screen_composer.dart';

/// Scherm 16: familiechat.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;
  bool _recording = false;
  final _recorder = AudioRecorder();
  DateTime? _clearedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cleared = await ref
          .read(chatStoreProvider)
          .clearedAt(widget.family.id);
      if (mounted) setState(() => _clearedAt = cleared);
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat wissen?'),
        content: const Text(
          'Je wist de berichten op dit toestel. Voor de anderen blijft de chat bestaan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wissen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final now = DateTime.now();
    await ref.read(chatStoreProvider).clear(widget.family.id, now);
    if (mounted) setState(() => _clearedAt = now);
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    final userId = ref.read(currentUserIdProvider);
    if (body.isEmpty || userId == null || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref
          .read(chatRepositoryProvider)
          .send(familyId: widget.family.id, userId: userId, body: body);
    } on Exception {
      if (mounted) {
        _input.text = body;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bericht versturen mislukt.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareLocation() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final position = await ref
        .read(deviceLocationSourceProvider)
        .currentPosition();
    if (position == null || !mounted) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .send(
            familyId: widget.family.id,
            userId: userId,
            body:
                'https://www.google.com/maps?q=${position.latitude},${position.longitude}',
          );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Locatie delen mislukt. Probeer opnieuw.'),
          ),
        );
      }
    }
  }

  Future<void> _photo() async {
    if (_sending || _recording) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Foto delen met je gezin?'),
          content: Image.file(
            File(photo.path),
            height: 220,
            fit: BoxFit.contain,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Versturen'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _upload(File(photo.path), 'image');
    } catch (_) {
      _mediaError();
    }
  }

  Future<void> _voice() async {
    if (_sending) return;
    try {
      if (_recording) {
        final path = await _recorder.stop();
        if (!mounted) return;
        setState(() => _recording = false);
        if (path == null) return;
        final file = File(path);
        try {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Spraakbericht versturen?'),
              content: const Text(
                'De opname is gestopt. Deel deze met je gezin of verwijder ze.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Verwijderen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Versturen'),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) await _upload(file, 'audio');
        } finally {
          if (await file.exists()) await file.delete();
        }
      } else {
        if (!await _recorder.hasPermission()) {
          _mediaError(
            'Geef microfoontoestemming om een spraakbericht op te nemen.',
          );
          return;
        }
        final dir = await getTemporaryDirectory();
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path:
              '${dir.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        if (mounted) setState(() => _recording = true);
      }
    } catch (_) {
      _mediaError();
    }
  }

  Future<void> _upload(File file, String kind) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _sending = true);
    try {
      final extension = kind == 'audio'
          ? 'm4a'
          : file.path.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      await ref
          .read(chatRepositoryProvider)
          .sendAttachment(
            familyId: widget.family.id,
            userId: userId,
            bytes: await file.readAsBytes(),
            kind: kind,
            extension: extension,
            mime: kind == 'audio'
                ? 'audio/mp4'
                : extension == 'png'
                ? 'image/png'
                : 'image/jpeg',
          );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _mediaError([
    String message = 'Bijlage kon niet worden verstuurd. Controleer je verbinding en probeer opnieuw.',
  ]) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final myId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(familyMessagesProvider(widget.family.id));
    final members =
        ref.watch(familyMembersProvider(widget.family.id)).value ?? const [];

    String nameOf(String userId) {
      for (final m in members) {
        if (m.userId == userId) return m.displayName;
      }
      return 'Gezinslid';
    }

    final all = messages.value ?? const <Message>[];
    final visible = [
      for (final m in all)
        if (_clearedAt == null || m.createdAt.isAfter(_clearedAt!)) m,
    ];

    return Scaffold(
      appBar: BrandedAppBar(
        title: 'Chat',
        actions: [
          if (visible.isNotEmpty)
            TextButton(onPressed: _clear, child: const Text('Wissen')),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.surfaceLow,
            child: Row(
              children: [
                for (final member in members.take(3))
                  Align(
                    widthFactor: .75,
                    child: MemberAvatar(member: member, size: 30),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.family.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${members.length} leden · Besloten gezinskring',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Bel een gezinslid',
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  onPressed: () => chooseContact(
                    context,
                    members.where((m) => m.userId != myId).toList(),
                  ),
                ),
                IconButton(
                  tooltip: 'Groepsinformatie',
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(widget.family.name),
                      content: Text(
                        members.map((m) => m.displayName).join('\n'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Sluiten'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Vandaag',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: messages.when(
              data: (_) => visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Nog geen berichten',
                      message: 'Stuur het eerste bericht naar je gezin.',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: EdgeInsets.all(tokens.spaceLg),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final message = visible[visible.length - 1 - i];
                        final mine = message.userId == myId;
                        return _Bubble(
                          message: message,
                          mine: mine,
                          name: mine ? null : nameOf(message.userId),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: 'Chat laden mislukt.\n$e',
                onRetry: () =>
                    ref.invalidate(familyMessagesProvider(widget.family.id)),
              ),
            ),
          ),
          if (_recording)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '● Opname actief · tik op stop om af te ronden',
                style: TextStyle(color: AppColors.alert),
              ),
            ),
          _Composer(
            onPhoto: _photo,
            onVoice: _voice,
            recording: _recording,
            controller: _input,
            sending: _sending,
            onSend: _send,
            onShareLocation: _shareLocation,
          ),
        ],
      ),
    );
  }
}
