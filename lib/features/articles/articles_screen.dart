import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/article.dart';
import '../../services/article_repository.dart';
import '../../widgets/common.dart';
import 'article_widgets.dart';

enum _Sort {
  recent('Récents', Icons.schedule),
  reactions('Populaires (réactions)', Icons.favorite_border),
  comments('Plus commentés', Icons.mode_comment_outlined);

  const _Sort(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Fil des publications : filtre par catégorie, recherche
/// (titre, auteur, mots-clés) et tri côté client.
class ArticlesScreen extends ConsumerStatefulWidget {
  const ArticlesScreen({super.key});

  @override
  ConsumerState<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends ConsumerState<ArticlesScreen> {
  ArticleCategory? _category;
  bool _searching = false;
  String _query = '';
  _Sort _sort = _Sort.recent;
  bool _fabExtended = true;

  List<Article> _apply(List<Article> list) {
    final visible = list.where((a) => a.matches(_query)).toList();
    switch (_sort) {
      case _Sort.recent:
        visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.reactions:
        visible.sort((a, b) => b.reactionTotal.compareTo(a.reactionTotal));
      case _Sort.comments:
        visible.sort((a, b) => b.commentCount.compareTo(a.commentCount));
    }
    return visible;
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final extend =
        n.direction != ScrollDirection.reverse || n.metrics.pixels <= 0;
    if (n.direction != ScrollDirection.idle && extend != _fabExtended) {
      setState(() => _fabExtended = extend);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(articlesProvider(_category));

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Titre, auteur, mot-clé…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('EduShare'),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: 'Trier les publications',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in _Sort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == _sort,
                  child: Text(s.label),
                ),
            ],
          ),
          IconButton(
            tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chip('Tout', null),
                for (final c in ArticleCategory.values) _chip(c.label, c),
              ],
            ),
          ),
        ),
      ),
      body: AsyncValueWidget(
        value: articles,
        onRetry: () => ref.invalidate(articlesProvider(_category)),
        data: (list) {
          final visible = _apply(list);
          if (visible.isEmpty) {
            return EmptyState(
              icon: Icons.library_books_outlined,
              message: _query.isEmpty
                  ? 'Aucune publication pour le moment.\nSoyez le premier à partager !'
                  : 'Aucun résultat pour « $_query ».',
            );
          }
          return NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(articlesProvider(_category).future),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 104),
                    itemCount: visible.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) return _header(context, visible.length);
                      return ArticleCard(
                        key: ValueKey(visible[i - 1].id),
                        article: visible[i - 1],
                        index: i - 1,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-article',
        tooltip: 'Publier une nouvelle publication',
        isExtended: _fabExtended,
        onPressed: () => context.push('/article/new'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Publier'),
      ),
    );
  }

  Widget _header(BuildContext context, int count) {
    final theme = Theme.of(context);
    final plural = count > 1 ? 's' : '';
    final text = _query.isEmpty
        ? '$count publication$plural · ${_sort.label}'
        : '$count résultat$plural pour « $_query » · ${_sort.label}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, ArticleCategory? category) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == category,
      onSelected: (_) => setState(() => _category = category),
    ),
  );
}
