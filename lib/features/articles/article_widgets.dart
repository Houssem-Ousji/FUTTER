import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/article.dart';
import '../../services/article_repository.dart';
import '../../widgets/common.dart';

IconData categoryIcon(ArticleCategory category) => switch (category) {
  ArticleCategory.article => Icons.article_outlined,
  ArticleCategory.research => Icons.science_outlined,
  ArticleCategory.courseSummary => Icons.menu_book_outlined,
  ArticleCategory.resource => Icons.folder_open_outlined,
};

/// Couleurs (fond, texte) de la puce de catégorie, issues du colorScheme.
(Color, Color) categoryColors(ColorScheme scheme, ArticleCategory category) =>
    switch (category) {
      ArticleCategory.article => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ArticleCategory.research => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ArticleCategory.courseSummary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ArticleCategory.resource => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
      ),
    };

/// Temps de lecture estimé (environ 200 mots par minute, 1 minute minimum).
int readingMinutes(String content) {
  final words = content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final minutes = (words.length / 200).ceil();
  return minutes < 1 ? 1 : minutes;
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category, this.large = false});

  final ArticleCategory category;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = categoryColors(theme.colorScheme, category);
    final style = large
        ? theme.textTheme.labelLarge
        : theme.textTheme.labelMedium;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(category), size: large ? 18 : 16, color: fg),
          Gaps.xs,
          Text(category.label, style: style?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, this.index = 0});

  final Article article;

  /// Position dans la liste : décale légèrement l'animation d'apparition.
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final minutes = readingMinutes(article.content);
    final delay = (index < 6 ? index : 6) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        onTap: () => context.push('/article/${article.id}'),
        label:
            '${article.category.label}. ${article.title}. '
            'Par ${article.authorName}, ${timeAgo(article.createdAt)}. '
            'Lecture $minutes min. '
            '${article.reactionTotal} réactions, '
            '${article.commentCount} commentaires.',
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/article/${article.id}'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryChip(category: article.category),
                      const Spacer(),
                      Text(timeAgo(article.createdAt), style: muted),
                    ],
                  ),
                  Gaps.md,
                  Text(article.title, style: theme.textTheme.titleMedium),
                  Gaps.sm,
                  Row(
                    children: [
                      UserAvatar(name: article.authorName, radius: 12),
                      Gaps.sm,
                      Flexible(
                        child: Text(
                          article.authorName,
                          style: theme.textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Gaps.sm,
                      Text(article.authorRole.label, style: muted),
                    ],
                  ),
                  Gaps.md,
                  Text(
                    article.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  Gaps.md,
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      Gaps.xs,
                      Text('${article.reactionTotal}', style: muted),
                      Gaps.md,
                      Icon(
                        Icons.mode_comment_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      Gaps.xs,
                      Text('${article.commentCount}', style: muted),
                      Gaps.md,
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      Gaps.xs,
                      Text('$minutes min', style: muted),
                      if (article.tags.isNotEmpty) ...[
                        Gaps.md,
                        Expanded(
                          child: Text(
                            article.tags.map((t) => '#$t').join(' '),
                            style: muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
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

/// Réactions : une seule par utilisateur, un nouveau toucher la retire.
class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final mine = ref.watch(myReactionProvider(article.id)).valueOrNull;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in ReactionType.values)
          _ReactionChip(
            type: type,
            count: article.reactionCount(type),
            selected: mine == type,
            onToggle: uid == null
                ? null
                : () async {
                    final removing = mine == type;
                    final ok = await guard(
                      () => ref
                          .read(articleRepositoryProvider)
                          .setReaction(article.id, uid, removing ? null : type),
                    );
                    if (ok && context.mounted) {
                      showSnack(
                        context,
                        removing
                            ? 'Réaction retirée'
                            : 'Réaction « ${type.label} » ajoutée',
                      );
                    }
                  },
          ),
      ],
    );
  }
}

class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    required this.type,
    required this.count,
    required this.selected,
    required this.onToggle,
  });

  final ReactionType type;
  final int count;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip> {
  bool _pulse = false;

  void _tap() {
    setState(() => _pulse = true);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _pulse = false);
    });
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.onToggle != null,
      excludeSemantics: true,
      label: '${t.label}, ${widget.count} réaction(s)',
      hint: widget.selected ? 'Toucher pour retirer' : 'Toucher pour réagir',
      onTap: widget.onToggle == null ? null : _tap,
      child: AnimatedScale(
        scale: _pulse ? 1.12 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: FilterChip(
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          selected: widget.selected,
          label: Text('${t.emoji} ${t.label} · ${widget.count}'),
          onSelected: widget.onToggle == null ? null : (_) => _tap(),
        ),
      ),
    );
  }
}

class CommentTile extends ConsumerWidget {
  const CommentTile({super.key, required this.comment, required this.article});

  final Comment comment;
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final canDelete =
        me != null &&
        (me.id == comment.authorId || me.id == article.authorId || me.isAdmin);
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Semantics(
        button: true,
        label: 'Profil de ${comment.authorName}',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/user/${comment.authorId}'),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: UserAvatar(name: comment.authorName, radius: 18),
            ),
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: comment.authorName,
              style: theme.textTheme.titleSmall,
            ),
            TextSpan(
              text:
                  '  ${comment.authorRole.label} · ${timeAgo(comment.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SelectableText(comment.text, style: theme.textTheme.bodyMedium),
      ),
      trailing: canDelete
          ? IconButton(
              tooltip: 'Supprimer le commentaire',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Supprimer le commentaire ?',
                  message: 'Cette action est définitive.',
                );
                if (!ok) return;
                await guard(
                  () => ref
                      .read(articleRepositoryProvider)
                      .deleteComment(article.id, comment.id),
                  success: 'Commentaire supprimé',
                );
              },
            )
          : null,
    );
  }
}
