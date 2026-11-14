import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/app_user.dart';
import '../../models/partner.dart';
import '../../services/partner_repository.dart';
import '../../widgets/common.dart';
import 'partner_widgets.dart';

/// Universités partenaires et fil de leurs annonces / opportunités.
class PartnersScreen extends ConsumerStatefulWidget {
  const PartnersScreen({super.key});

  @override
  ConsumerState<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends ConsumerState<PartnersScreen> {
  AnnouncementType? _type;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partners = ref.watch(partnersProvider);
    final announcements = ref.watch(announcementsProvider(null));

    final counts = <String, int>{};
    for (final a in announcements.valueOrNull ?? const <Announcement>[]) {
      counts[a.partnerId] = (counts[a.partnerId] ?? 0) + 1;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partenaires'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Annonces & opportunités'),
            Tab(text: 'Universités'),
          ]),
        ),
        body: TabBarView(
          children: [
            AsyncValueWidget(
              value: announcements,
              onRetry: () => ref.invalidate(announcementsProvider(null)),
              data: _announcementsTab,
            ),
            AsyncValueWidget(
              value: partners,
              onRetry: () => ref.invalidate(partnersProvider),
              data: (list) => _partnersTab(list, counts),
            ),
          ],
        ),
        floatingActionButton: _fab(context, me),
      ),
    );
  }

  Widget _announcementsTab(List<Announcement> list) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.campaign_outlined,
        message: 'Aucune annonce publiée pour le moment.',
      );
    }
    final filtered = _type == null ? list : list.where((a) => a.type == _type).toList();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _filterChip('Toutes', null),
              for (final t in AnnouncementType.values) _filterChip(_pluralLabel(t), t),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: announcementIcon(_type!),
                  message: 'Aucune publication de ce type pour le moment.',
                  action: TextButton(
                    onPressed: () => setState(() => _type = null),
                    child: const Text('Voir toutes les annonces'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 88),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => AnnouncementCard(announcement: filtered[i]),
                ),
        ),
      ],
    );
  }

  String _pluralLabel(AnnouncementType t) => switch (t) {
        AnnouncementType.announcement => 'Annonces',
        AnnouncementType.event => 'Événements',
        AnnouncementType.opportunity => 'Opportunités',
      };

  Widget _filterChip(String label, AnnouncementType? type) {
    final selected = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          child: FilterChip(
            label: Text(label),
            avatar: type == null ? null : Icon(announcementIcon(type), size: 18),
            selected: selected,
            showCheckmark: type == null,
            onSelected: (_) => setState(() => _type = type),
          ),
        ),
      ),
    );
  }

  Widget _partnersTab(List<Partner> list, Map<String, int> counts) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_outlined,
        message: 'Aucune université partenaire référencée.',
      );
    }
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? list
        : list
            .where((p) => '${p.name} ${p.city} ${p.country}'.toLowerCase().contains(q))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Rechercher par nom, ville ou pays',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  message: 'Aucune université ne correspond à votre recherche.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 88),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      PartnerTile(partner: filtered[i], announcementCount: counts[filtered[i].id]),
                ),
        ),
      ],
    );
  }

  Widget? _fab(BuildContext context, AppUser? me) {
    if (me == null) return null;
    if (me.isAdmin) {
      return FloatingActionButton.extended(
        heroTag: 'new-partner',
        onPressed: () => context.push('/partner/new'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une université'),
      );
    }
    final partnerId = me.partnerId;
    if (me.role == UserRole.partner && partnerId != null) {
      return FloatingActionButton.extended(
        heroTag: 'new-announcement',
        onPressed: () => context.push('/partner/$partnerId/announce'),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Publier une annonce'),
      );
    }
    return null;
  }
}
