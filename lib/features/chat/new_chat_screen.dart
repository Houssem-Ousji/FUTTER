import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/user_repository.dart';
import '../../widgets/common.dart';
import 'chat_actions.dart';

/// Choix du destinataire d'une nouvelle conversation.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final users = ref.watch(allUsersProvider);
    final q = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher un membre…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AsyncValueWidget(
            value: users,
            onRetry: () => ref.invalidate(allUsersProvider),
            data: (list) {
              final visible = list
                  .where((u) => u.id != uid)
                  .where((u) =>
                      q.isEmpty ||
                      u.displayName.toLowerCase().contains(q) ||
                      u.university.toLowerCase().contains(q))
                  .toList();
              if (visible.isEmpty) {
                return const EmptyState(icon: Icons.person_search, message: 'Aucun membre trouvé.');
              }
              return ListView.builder(
                itemCount: visible.length,
                itemBuilder: (_, i) => UserTile(
                  user: visible[i],
                  onTap: () => startConversation(context, ref, visible[i], replace: true),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
