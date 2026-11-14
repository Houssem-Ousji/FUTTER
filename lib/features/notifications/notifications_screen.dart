import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../services/notification_repository.dart';
import '../../widgets/common.dart';

/// Alertes en temps réel (commentaires, réactions…), créées par les
/// Cloud Functions. Glisser une alerte pour la supprimer (annulable).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// Alertes consécutives fusionnées pour l'affichage (même type et même cible).
class _Entry {
  _Entry(this.items);

  final List<AppNotification> items;

  AppNotification get first => items.first;
  bool get unread => items.any((n) => !n.read);
  int get unreadCount => items.where((n) => !n.read).length;
}

sealed class _Row {}

class _HeaderRow extends _Row {
  _HeaderRow(this.label);
  final String label;
}

class _EntryRow extends _Row {
  _EntryRow(this.entry);
  final _Entry entry;
}

const _reactedMarker = ' a réagi à ';

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _undoDelay = Duration(seconds: 5);

  /// Alertes masquées en attente de suppression réelle (annulable).
  final Set<String> _hidden = {};
  final Map<String, Timer> _timers = {};
  String? _uid;

  @override
  void dispose() {
    // Valide les suppressions en attente plutôt que de les perdre.
    final uid = _uid;
    for (final entry in _timers.entries) {
      entry.value.cancel();
      if (uid != null) {
        final repo = ref.read(notificationRepositoryProvider);
        unawaited(repo.delete(uid, entry.key).catchError((_) {}));
      }
    }
    _timers.clear();
    super.dispose();
  }

  void _deleteWithUndo(String uid, _Entry entry) {
    final repo = ref.read(notificationRepositoryProvider);
    final ids = [for (final n in entry.items) n.id];
    setState(() => _hidden.addAll(ids));
    for (final id in ids) {
      _timers[id] = Timer(_undoDelay, () async {
        _timers.remove(id);
        final ok = await guard(() => repo.delete(uid, id));
        if (!mounted) return;
        if (!ok) setState(() => _hidden.remove(id));
      });
    }
    showSnack(
      context,
      ids.length > 1 ? '${ids.length} alertes supprimées' : 'Alerte supprimée',
      actionLabel: 'Annuler',
      onAction: () {
        for (final id in ids) {
          _timers.remove(id)?.cancel();
        }
        if (mounted) setState(() => _hidden.removeAll(ids));
      },
    );
  }

  Future<void> _open(String uid, _Entry entry) async {
    final repo = ref.read(notificationRepositoryProvider);
    final unread = entry.items.where((n) => !n.read).toList();
    if (unread.isNotEmpty) {
      unawaited(guard(() => repo.markAllRead(uid, unread)));
    }
    if (entry.first.route.startsWith('/')) context.push(entry.first.route);
  }

  Future<void> _markAll(String uid, List<AppNotification> list) async {
    final repo = ref.read(notificationRepositoryProvider);
    final ok = await guard(() => repo.markAllRead(uid, list));
    if (ok && mounted) showSnack(context, 'Toutes les alertes sont marquées comme lues.');
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    try {
      await ref.read(notificationsProvider.future);
    } catch (_) {
      // L'erreur est affichée par l'état du provider.
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    _uid = uid;
    final notifications = ref.watch(notificationsProvider);
    final unreadTotal = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          if (unreadTotal > 0 && uid != null)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Tout marquer comme lu',
              onPressed: () => _markAll(uid, notifications.valueOrNull ?? const []),
            ),
          Gaps.xs,
        ],
      ),
      body: AsyncValueWidget(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (all) {
          final list = all.where((n) => !_hidden.contains(n.id)).toList();
          if (list.isEmpty || uid == null) {
            return const EmptyState(
              icon: Icons.notifications_none,
              message: 'Aucune alerte pour le moment.',
            );
          }
          final rows = _buildRows(list, DateTime.now());
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => switch (rows[i]) {
                    _HeaderRow(:final label) => _SectionHeader(label),
                    _EntryRow(:final entry) => _NotificationTile(
                        key: ValueKey(entry.items.map((n) => n.id).join('|')),
                        entry: entry,
                        onOpen: () => _open(uid, entry),
                        onDelete: () => _deleteWithUndo(uid, entry),
                      ),
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _section(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff < 7) return 'Cette semaine';
    return 'Plus ancien';
  }

  static String? _target(AppNotification n) {
    if (n.type != 'reaction') return null;
    final i = n.body.indexOf(_reactedMarker);
    if (i < 0) return null;
    return n.body.substring(i + _reactedMarker.length);
  }

  static bool _sameGroup(AppNotification a, AppNotification b) {
    final ta = _target(a);
    return ta != null && a.type == b.type && a.route == b.route && ta == _target(b);
  }

  List<_Row> _buildRows(List<AppNotification> list, DateTime now) {
    final rows = <_Row>[];
    String? currentSection;
    _Entry? last;
    for (final n in list) {
      final section = _section(n.createdAt, now);
      if (section != currentSection) {
        currentSection = section;
        rows.add(_HeaderRow(section));
        last = null;
      }
      if (last != null && _sameGroup(last.items.last, n)) {
        last.items.add(n);
      } else {
        last = _Entry([n]);
        rows.add(_EntryRow(last));
      }
    }
    return rows;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onDelete,
  });

  final _Entry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  IconData get _icon => switch (entry.first.type) {
        'comment' => Icons.mode_comment_outlined,
        'reaction' => Icons.favorite_border,
        'announcement' => Icons.campaign_outlined,
        _ => Icons.notifications_outlined,
      };

  ({String title, String body}) _texts() {
    final items = entry.items;
    if (items.length == 1) return (title: items.first.title, body: items.first.body);
    final names = <String>[];
    for (final n in items) {
      final name = n.body.substring(0, n.body.indexOf(_reactedMarker)).trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    final target = _NotificationsScreenState._target(items.first) ?? '';
    final others = names.length - 2;
    final who = switch (names.length) {
      0 || 1 => '${items.length} personnes',
      2 => '${names[0]} et ${names[1]}',
      3 => '${names[0]}, ${names[1]} et 1 autre',
      _ => '${names[0]}, ${names[1]} et $others autres',
    };
    return (title: 'Nouvelles réactions', body: '$who ont réagi à $target');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final unread = entry.unread;
    final texts = _texts();
    final time = timeAgo(entry.first.createdAt);
    final background = unread
        ? Color.alphaBlend(scheme.primaryContainer.withValues(alpha: 0.35), scheme.surface)
        : scheme.surface;

    return Dismissible(
      key: ValueKey('d-${entry.first.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Semantics(
        button: true,
        label: '${unread ? 'Non lue. ' : ''}${texts.title}. ${texts.body}. $time',
        excludeSemantics: true,
        onTap: onOpen,
        onDismiss: onDelete,
        customSemanticsActions: {
          CustomSemanticsAction(label: 'Supprimer'): onDelete,
        },
        child: Material(
          color: background,
          child: InkWell(
            onTap: onOpen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: IntrinsicHeight(
               child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    color: unread ? scheme.primary : Colors.transparent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                unread ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                            foregroundColor:
                                unread ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                            child: Icon(_icon),
                          ),
                          Gaps.md,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  texts.title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                Gaps.xs,
                                Text(
                                  texts.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                Gaps.xs,
                                Text(
                                  time,
                                  style: textTheme.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (unread) ...[
                            Gaps.sm,
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
               ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
