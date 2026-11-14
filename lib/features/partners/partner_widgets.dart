import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/partner.dart';
import '../../services/partner_repository.dart';
import '../../widgets/common.dart';

IconData announcementIcon(AnnouncementType type) => switch (type) {
      AnnouncementType.announcement => Icons.campaign_outlined,
      AnnouncementType.event => Icons.event_outlined,
      AnnouncementType.opportunity => Icons.work_outline,
    };

/// Initiales (2 lettres max) d'un nom d'université.
String partnerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.length > 1 && p[0].toUpperCase() != p[0].toLowerCase())
      .toList();
  if (parts.isEmpty) return name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  final first = parts.first[0];
  final second = parts.length > 1 ? parts[1][0] : '';
  return (first + second).toUpperCase();
}

/// Couleurs (fond, texte) d'une puce de type, issues du colorScheme.
(Color, Color) announcementColors(ColorScheme scheme, AnnouncementType type) => switch (type) {
      AnnouncementType.announcement => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      AnnouncementType.event => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AnnouncementType.opportunity => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final AnnouncementType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = announcementColors(theme.colorScheme, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(announcementIcon(type), size: 16, color: fg),
          Gaps.xs,
          Text(type.label, style: theme.textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Avatar d'initiales sur fond colorScheme.
class PartnerAvatar extends StatelessWidget {
  const PartnerAvatar({super.key, required this.name, this.radius = 24});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          partnerInitials(name),
          style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class PartnerTile extends StatelessWidget {
  const PartnerTile({super.key, required this.partner, this.announcementCount});

  final Partner partner;

  /// Nombre d'annonces publiées, si connu.
  final int? announcementCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = announcementCount;
    final countLabel =
        count == null || count == 0 ? null : (count == 1 ? '1 annonce' : '$count annonces');
    return Semantics(
      button: true,
      label: [
        'Université ${partner.name}',
        if (partner.location.isNotEmpty) partner.location,
        if (countLabel != null) countLabel,
      ].join(', '),
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/partner/${partner.id}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    PartnerAvatar(name: partner.name),
                    Gaps.md,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(partner.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium),
                          if (partner.location.isNotEmpty) ...[
                            Gaps.xs,
                            Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 14, color: scheme.onSurfaceVariant),
                                Gaps.xs,
                                Expanded(
                                  child: Text(partner.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: scheme.onSurfaceVariant)),
                                ),
                              ],
                            ),
                          ],
                          if (countLabel != null) ...[
                            Gaps.sm,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(countLabel,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: scheme.onSecondaryContainer)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
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

/// Échéance relative d'une annonce : texte et urgence.
class DueInfo {
  const DueInfo(this.text, {this.urgent = false, this.past = false});

  final String text;

  /// Moins de 14 jours.
  final bool urgent;

  /// Date dépassée.
  final bool past;
}

DueInfo dueInfo(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (days < 0) return const DueInfo('terminé', past: true);
  if (days == 0) return const DueInfo("aujourd'hui", urgent: true);
  if (days == 1) return const DueInfo('demain', urgent: true);
  return DueInfo('dans $days jours', urgent: days < 14);
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement, this.showPartner = true});

  final Announcement announcement;
  final bool showPartner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = announcement;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Semantics(
      button: true,
      label: [
        a.type.label,
        a.title,
        if (showPartner) a.partnerName,
        if (a.eventDate != null) '${_dateLabel(a)}, ${dueInfo(a.eventDate!).text}',
        'Publié ${timeAgo(a.createdAt)}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showAnnouncementDetails(context, a),
            child: Padding(
              padding: Gaps.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeChip(type: a.type),
                      const Spacer(),
                      Text(timeAgo(a.createdAt), style: muted),
                    ],
                  ),
                  Gaps.sm,
                  Text(a.title, style: theme.textTheme.titleMedium),
                  if (showPartner) ...[
                    Gaps.xs,
                    Row(
                      children: [
                        Icon(Icons.account_balance_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        Gaps.xs,
                        Expanded(child: Text(a.partnerName, style: muted)),
                      ],
                    ),
                  ],
                  if (a.eventDate != null) ...[
                    Gaps.sm,
                    _DueBadge(announcement: a),
                  ],
                  Gaps.sm,
                  Text(a.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.announcement, this.large = false});

  final Announcement announcement;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = dueInfo(announcement.eventDate!);
    final (bg, fg) = info.urgent
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : info.past
            ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
            : (scheme.secondaryContainer, scheme.onSecondaryContainer);
    final style = large ? theme.textTheme.titleSmall : theme.textTheme.labelMedium;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 8, vertical: large ? 12 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.urgent ? Icons.schedule : Icons.event_outlined,
              size: large ? 20 : 16, color: fg),
          Gaps.sm,
          Flexible(
            child: Text(
              '${_dateLabel(announcement)} (${info.text})',
              style: style?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(Announcement a) => a.type == AnnouncementType.opportunity
    ? 'Date limite : ${formatDate(a.eventDate!)}'
    : 'Le ${formatDate(a.eventDate!)}';

/// Copie [text] dans le presse-papiers et confirme par un message.
Future<void> copyToClipboard(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, message);
}

Future<void> showAnnouncementDetails(BuildContext context, Announcement a) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AnnouncementSheet(announcement: a),
    );

class _AnnouncementSheet extends ConsumerWidget {
  const _AnnouncementSheet({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = ref.watch(currentUserProvider).valueOrNull;
    final canDelete = me != null && (me.isAdmin || me.id == a.authorId);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Align(alignment: Alignment.centerLeft, child: _TypeChip(type: a.type)),
          Gaps.sm,
          Text(a.title, style: theme.textTheme.headlineSmall),
          Gaps.xs,
          Semantics(
            button: true,
            label: 'Ouvrir la fiche de ${a.partnerName}',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push('/partner/${a.partnerId}');
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      a.partnerName,
                      style: TextStyle(
                        color: scheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (a.eventDate != null) ...[
            Gaps.sm,
            Align(
              alignment: Alignment.centerLeft,
              child: _DueBadge(announcement: a, large: true),
            ),
          ],
          Gaps.md,
          SelectableText(a.description, style: theme.textTheme.bodyLarge),
          if (a.link.isNotEmpty) ...[
            Gaps.md,
            Card(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: const Text("Plus d'informations"),
                subtitle: SelectableText(a.link),
                trailing: IconButton(
                  tooltip: 'Copier le lien',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => copyToClipboard(context, a.link, 'Lien copié'),
                ),
              ),
            ),
          ],
          Gaps.md,
          Text('Publié le ${formatDate(a.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (canDelete) ...[
            Gaps.md,
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text("Supprimer l'annonce"),
              onPressed: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: "Supprimer l'annonce ?",
                  message: 'Cette action est définitive.',
                );
                if (!confirmed) return;
                final ok = await guard(
                  () => ref.read(partnerRepositoryProvider).deleteAnnouncement(a.id),
                  success: 'Annonce supprimée',
                );
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}
