import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/partner.dart';
import '../../services/partner_repository.dart';
import '../../widgets/common.dart';
import 'partner_widgets.dart';

class PartnerDetailScreen extends ConsumerWidget {
  const PartnerDetailScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerAsync = ref.watch(partnerProvider(partnerId));
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = partnerAsync.valueOrNull;
    final isAdmin = me?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(partner?.name ?? 'Université partenaire'),
        actions: [
          if (isAdmin && partner != null) ...[
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/partner/$partnerId/edit'),
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, partner),
            ),
          ],
        ],
      ),
      body: AsyncValueWidget(
        value: partnerAsync,
        onRetry: () => ref.invalidate(partnerProvider(partnerId)),
        data: (p) => p == null
            ? const EmptyState(
                icon: Icons.account_balance_outlined,
                message: "Cette université n'est plus référencée.",
              )
            : _PartnerContent(partner: p),
      ),
      floatingActionButton: partner != null && (me?.canPublishFor(partnerId) ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/partner/$partnerId/announce'),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Publier une annonce'),
            )
          : null,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Partner partner) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Retirer ${partner.name} ?',
      message: "L'université et toutes ses annonces seront supprimées.",
    );
    if (!confirmed) return;
    final ok = await guard(
      () => ref.read(partnerRepositoryProvider).deletePartner(partner.id),
      success: 'Université retirée',
    );
    if (ok && context.mounted) popOrHome(context);
  }
}

class _PartnerContent extends ConsumerWidget {
  const _PartnerContent({required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final announcements = ref.watch(announcementsProvider(partner.id));

    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primaryContainer, scheme.secondaryContainer],
            ),
          ),
          child: Column(
            children: [
              PartnerAvatar(name: partner.name, radius: 44),
              Gaps.md,
              Semantics(
                header: true,
                child: Text(
                  partner.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
              if (partner.location.isNotEmpty) ...[
                Gaps.xs,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: scheme.onPrimaryContainer),
                    Gaps.xs,
                    Flexible(
                      child: Text(partner.location,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onPrimaryContainer)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: Gaps.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (partner.website.isNotEmpty || partner.contactEmail.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (partner.website.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => copyToClipboard(
                            context, partner.website, 'Adresse du site copiée'),
                        icon: const Icon(Icons.language),
                        label: const Text('Visiter le site'),
                      ),
                    if (partner.contactEmail.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => copyToClipboard(
                            context, partner.contactEmail, 'Adresse e-mail copiée'),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Écrire'),
                      ),
                  ],
                ),
              if (partner.description.isNotEmpty) ...[
                Gaps.md,
                SelectableText(partner.description, style: theme.textTheme.bodyLarge),
              ],
              if (partner.website.isNotEmpty) ...[
                Gaps.md,
                Row(children: [
                  Icon(Icons.language, size: 18, color: scheme.onSurfaceVariant),
                  Gaps.sm,
                  Expanded(child: SelectableText(partner.website)),
                ]),
              ],
              if (partner.contactEmail.isNotEmpty) ...[
                Gaps.sm,
                Row(children: [
                  Icon(Icons.mail_outline, size: 18, color: scheme.onSurfaceVariant),
                  Gaps.sm,
                  Expanded(child: SelectableText(partner.contactEmail)),
                ]),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Semantics(
            header: true,
            child: Text('Annonces et opportunités', style: theme.textTheme.titleMedium),
          ),
        ),
        announcements.when(
          loading: () => const SizedBox(height: 240, child: SkeletonList(count: 2)),
          error: (e, _) => SizedBox(
            height: 240,
            child: ErrorState(
              message: 'Erreur de chargement : $e',
              onRetry: () => ref.invalidate(announcementsProvider(partner.id)),
            ),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: Gaps.screenPadding,
                  child: Text('Aucune annonce pour le moment.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                )
              : Column(
                  children: [
                    for (final a in list) AnnouncementCard(announcement: a, showPartner: false),
                  ],
                ),
        ),
      ],
    );
  }
}
