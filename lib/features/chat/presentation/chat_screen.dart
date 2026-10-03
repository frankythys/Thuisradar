import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../application/chat_providers.dart';
import '../domain/message.dart';

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

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    final userId = ref.read(currentUserIdProvider);
    if (body.isEmpty || userId == null || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref.read(chatRepositoryProvider).send(familyId: widget.family.id, userId: userId, body: body);
    } on Exception {
      if (mounted) {
        _input.text = body;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bericht versturen mislukt.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final myId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(familyMessagesProvider(widget.family.id));
    final members = ref.watch(familyMembersProvider(widget.family.id)).value ?? const [];

    String nameOf(String userId) {
      for (final m in members) {
        if (m.userId == userId) return m.displayName;
      }
      return 'Gezinslid';
    }

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Chat'),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Nog geen berichten',
                      message: 'Stuur het eerste bericht naar je gezin.',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: EdgeInsets.all(tokens.spaceLg),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final message = list[list.length - 1 - i];
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
                onRetry: () => ref.invalidate(familyMessagesProvider(widget.family.id)),
              ),
            ),
          ),
          _Composer(controller: _input, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.name});

  final Message message;
  final bool mine;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: tokens.spaceSm),
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(tokens.radiusInput),
          boxShadow: mine ? null : tokens.shadowLevel1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null) Text(name!, style: text.labelMedium?.copyWith(color: AppColors.primary)),
            Text(message.body, style: text.bodyLarge?.copyWith(color: mine ? Colors.white : AppColors.ink)),
            const SizedBox(height: 2),
            Text(
              formatClock(message.createdAt),
              style: text.labelSmall?.copyWith(color: mine ? Colors.white70 : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceSm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Bericht'),
              ),
            ),
            SizedBox(width: tokens.spaceSm),
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
