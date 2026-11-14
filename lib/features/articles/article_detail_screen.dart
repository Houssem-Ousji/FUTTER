import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/article.dart';
import '../../services/article_repository.dart';
import '../../widgets/common.dart';
import 'article_widgets.dart';

class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleProvider(articleId));
    final me = ref.watch(currentUserProvider).valueOrNull;
    final article = articleAsync.valueOrNull;
    final isAuthor = article != null && me?.id == article.authorId;
    final canDelete = article != null && (isAuthor || (me?.isAdmin ?? false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publication'),
        actions: [
          if (isAuthor)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/article/$articleId/edit'),
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: AsyncValueWidget(
        value: articleAsync,
        onRetry: () => ref.invalidate(articleProvider(articleId)),
        data: (article) => article == null
            ? const EmptyState(
                icon: Icons.delete_sweep_outlined,
                message: "Cette publication n'existe plus.",
              )
            : Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _ArticleContent(article: article),
                      ),
                    ),
                  ),
                  _CommentInput(articleId: article.id),
                ],
              ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Supprimer la publication ?',
      message:
          'Les commentaires et réactions associés seront également supprimés.',
    );
    if (!confirmed) return;
    final ok = await guard(
      () => ref.read(articleRepositoryProvider).delete(articleId),
      success: 'Publication supprimée',
    );
    if (ok && context.mounted) popOrHome(context);
  }
}

class _ArticleContent extends ConsumerWidget {
  const _ArticleContent({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final comments = ref.watch(commentsProvider(article.id));
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CategoryChip(category: article.category, large: true),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Gaps.xs,
                  Text(
                    'Lecture : ${readingMinutes(article.content)} min',
                    style: muted,
                  ),
                ],
              ),
            ],
          ),
        ),
        Gaps.md,
        Semantics(
          header: true,
          child: Text(article.title, style: theme.textTheme.headlineSmall),
        ),
        Gaps.md,
        InkWell(
          onTap: () => context.push('/user/${article.authorId}'),
          child: Row(
            children: [
              UserAvatar(name: article.authorName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            article.authorName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Gaps.sm,
                        RoleBadge(role: article.authorRole),
                      ],
                    ),
                    Text(
                      '${formatDateTime(article.createdAt)}'
                      '${article.wasEdited ? ' · modifié' : ''}',
                      style: muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 32),
        if (article.tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in article.tags)
                Chip(
                  label: Text('#$tag'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        Gaps.md,
        SelectableText(
          article.content,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
        if (article.attachmentUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Document joint'),
              subtitle: SelectableText(article.attachmentUrl),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ReactionBar(article: article),
        const Divider(height: 32),
        Text(
          'Commentaires (${article.commentCount})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        comments.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorState(
            message: 'Erreur de chargement des commentaires : $e',
            onRetry: () => ref.invalidate(commentsProvider(article.id)),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      Gaps.sm,
                      Expanded(
                        child: Text(
                          'Aucun commentaire. Lancez la discussion !',
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final c in list)
                      CommentTile(comment: c, article: article),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CommentInput extends ConsumerStatefulWidget {
  const _CommentInput({required this.articleId});

  final String articleId;

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final me = ref.read(currentUserProvider).valueOrNull;
    if (text.isEmpty || me == null) return;
    if (text.length > 2000) {
      showMessage('Commentaire trop long (2000 caractères maximum).');
      return;
    }
    setState(() => _sending = true);
    final ok = await guard(
      () => ref
          .read(articleRepositoryProvider)
          .addComment(widget.articleId, me, text),
      success: 'Commentaire publié',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter un commentaire…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Publier le commentaire',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
