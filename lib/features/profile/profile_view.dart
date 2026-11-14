import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/article.dart';
import '../../services/article_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/simple_bar_chart.dart';
import '../articles/article_widgets.dart';
import '../chat/chat_actions.dart';

/// Profil d'un membre : identité, statistiques d'activité, graphique des
/// publications sur 6 mois et liste des publications.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key, required this.user, required this.isMe});

  final AppUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final articles = ref.watch(articlesByAuthorProvider(user.id));
    final affiliation =
        [user.university, user.fieldOfStudy].where((s) => s.isNotEmpty).join(' · ');

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scheme.primaryContainer.withValues(alpha: 0.55), scheme.surface],
            ),
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: UserAvatar(name: user.displayName, radius: 52),
              ),
              Gaps.md,
              Text(
                user.displayName,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Gaps.xs,
              RoleBadge(role: user.role),
              if (affiliation.isNotEmpty) ...[
                Gaps.sm,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_outlined, size: 18, color: scheme.onSurfaceVariant),
                    Gaps.sm,
                    Flexible(
                      child: Text(
                        affiliation,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
              if (user.bio.isNotEmpty) ...[
                Gaps.md,
                Text(user.bio, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              ],
              Gaps.sm,
              Text(
                'Membre depuis ${formatDate(user.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
              Gaps.md,
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!isMe)
                    FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Envoyer un message'),
                      onPressed: () => startConversation(context, ref, user),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Copier le lien du profil'),
                    onPressed: () async {
                      final link = kIsWeb
                          ? '${Uri.base.origin}/user/${user.id}'
                          : 'edushare://user/${user.id}';
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) showSnack(context, 'Lien du profil copié');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        _centered(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.article_outlined,
                  label: 'Publications',
                  value: user.stats.articles,
                ),
              ),
              Gaps.sm,
              Expanded(
                child: _StatCard(
                  icon: Icons.chat_outlined,
                  label: 'Commentaires',
                  value: user.stats.comments,
                ),
              ),
              Gaps.sm,
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite_border,
                  label: 'Réactions reçues',
                  value: user.stats.reactionsReceived,
                ),
              ),
            ],
          ),
        )),
        _centered(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Publications sur les 6 derniers mois'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                  child: articles.when(
                    loading: () => const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => ErrorState(
                      message: 'Impossible de charger les publications.',
                      onRetry: () => ref.invalidate(articlesByAuthorProvider(user.id)),
                    ),
                    data: (list) => _ActivityChart(articles: list),
                  ),
                ),
              ),
              const SectionTitle('Publications'),
            ],
          ),
        )),
        _centered(articles.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Aucune publication pour le moment.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : Column(children: [for (final a in list) ArticleCard(article: a)]),
        )),
      ],
    );
  }

  static Widget _centered(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: '$label : $value',
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                Gaps.xs,
                Text('$value', style: theme.textTheme.headlineSmall),
                Gaps.xs,
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.articles});

  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
    final counts = [
      for (final m in months)
        articles
            .where((a) => a.createdAt.year == m.year && a.createdAt.month == m.month)
            .length,
    ];
    return SimpleBarChart(
      labels: months.map(formatMonth).toList(),
      values: counts,
      semanticLabel: 'Publications sur les 6 derniers mois',
    );
  }
}
