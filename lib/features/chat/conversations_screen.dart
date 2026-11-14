import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../models/chat.dart';
import '../../services/chat_repository.dart';
import '../../widgets/common.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  static const _avatarRadius = 28.0;
  // 16 (marge) + 56 (avatar) + 16 (espace) : aligne le séparateur sur le texte.
  static const _dividerIndent = 88.0;

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(
            children: [
              AsyncValueWidget(
                value: conversations,
                onRetry: () => ref.invalidate(conversationsProvider),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.forum_outlined,
                      message: 'Aucune conversation.\nÉcrivez à un étudiant ou à un enseignant !',
                    );
                  }
                  final q = _query.trim().toLowerCase();
                  final visible = q.isEmpty
                      ? list
                      : list
                          .where((c) =>
                              c.otherName(uid).toLowerCase().contains(q) ||
                              c.lastMessage.toLowerCase().contains(q))
                          .toList();
                  return Column(
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? const EmptyState(
                                icon: Icons.search_off,
                                message: 'Aucune conversation ne correspond à votre recherche.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 96),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, indent: _dividerIndent, endIndent: 16),
                                itemBuilder: (context, i) =>
                                    _ConversationTile(conversation: visible[i], uid: uid),
                              ),
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'new-chat',
                  tooltip: 'Nouveau message',
                  onPressed: () => context.push('/chat/new'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Nouveau message'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher une conversation…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close),
                      onPressed: onClear,
                    ),
            ),
          ),
        ),
      );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.uid});

  final Conversation conversation;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final scheme = Theme.of(context).colorScheme;
    final unread = c.isUnreadFor(uid);
    final name = c.otherName(uid);
    final preview = c.lastMessage.isEmpty
        ? 'Nouvelle conversation'
        : (c.lastSenderId == uid ? 'Vous : ${c.lastMessage}' : c.lastMessage);
    final weight = unread ? FontWeight.w700 : FontWeight.normal;

    return ListTile(
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: UserAvatar(name: name, radius: _ConversationsScreenState._avatarRadius),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: weight,
          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeAgo(c.lastMessageAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: unread ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
                ),
          ),
          if (unread) ...[
            const SizedBox(height: 6),
            Semantics(
              label: 'Message non lu',
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/chat/${c.id}'),
    );
  }
}
