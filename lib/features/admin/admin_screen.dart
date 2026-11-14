import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/article.dart';
import '../../services/partner_repository.dart';
import '../../services/stats_repository.dart';
import '../../services/user_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/simple_bar_chart.dart';

/// Tableau de bord administrateur : statistiques de la plateforme et
/// gestion des rôles.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(tabs: [Tab(text: 'Statistiques'), Tab(text: 'Utilisateurs')]),
        ),
        body: AsyncValueWidget(
          value: me,
          data: (user) => user?.isAdmin != true
              ? const EmptyState(
                  icon: Icons.lock_outline,
                  message: 'Accès réservé aux administrateurs.',
                )
              : TabBarView(children: [const _StatsTab(), _UsersTab(adminId: user!.id)]),
        ),
      ),
    );
  }
}

/// Couleurs (fond, contenu) associées à chaque rôle, issues du colorScheme.
(Color, Color) _roleColors(ColorScheme s, UserRole? role) => switch (role) {
      UserRole.student => (s.primaryContainer, s.onPrimaryContainer),
      UserRole.teacher => (s.tertiaryContainer, s.onTertiaryContainer),
      UserRole.admin => (s.errorContainer, s.onErrorContainer),
      UserRole.partner => (s.secondaryContainer, s.onSecondaryContainer),
      null => (s.surfaceContainerHighest, s.onSurface),
    };

IconData _roleIcon(UserRole? role) => switch (role) {
      UserRole.student => Icons.school_outlined,
      UserRole.teacher => Icons.menu_book_outlined,
      UserRole.admin => Icons.admin_panel_settings_outlined,
      UserRole.partner => Icons.handshake_outlined,
      null => Icons.groups_outlined,
    };

class _AdminStatTile extends StatelessWidget {
  const _AdminStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final int value;
  final IconData icon;
  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label : $value',
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.$1,
                  foregroundColor: colors.$2,
                  child: Icon(icon, size: 22),
                ),
                Gaps.md,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$value', style: theme.textTheme.headlineSmall),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(platformStatsProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(platformStatsProvider.future),
      child: AsyncValueWidget(
        value: stats,
        onRetry: () => ref.invalidate(platformStatsProvider),
        data: (s) {
          Widget grid(List<Widget> tiles) => LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 520 ? 3 : 2;
                final w = (box.maxWidth - 8 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final t in tiles) SizedBox(width: w, child: t)],
                );
              });
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Membres'),
                      grid([
                        _AdminStatTile(
                          label: 'Total',
                          value: s.totalUsers,
                          icon: _roleIcon(null),
                          colors: _roleColors(scheme, null),
                        ),
                        for (final role in UserRole.values)
                          _AdminStatTile(
                            label: role.label,
                            value: s.usersByRole[role] ?? 0,
                            icon: _roleIcon(role),
                            colors: _roleColors(scheme, role),
                          ),
                      ]),
                      SectionTitle('Contenus publiés (${s.totalArticles})'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                          child: SimpleBarChart(
                            labels: [for (final c in ArticleCategory.values) c.shortLabel],
                            values: [
                              for (final c in ArticleCategory.values)
                                s.articlesByCategory[c] ?? 0,
                            ],
                            semanticLabel: 'Contenus publiés par catégorie',
                          ),
                        ),
                      ),
                      const SectionTitle('Partenariats'),
                      grid([
                        _AdminStatTile(
                          label: 'Universités',
                          value: s.partners,
                          icon: Icons.account_balance_outlined,
                          colors: (scheme.secondaryContainer, scheme.onSecondaryContainer),
                        ),
                        _AdminStatTile(
                          label: 'Annonces',
                          value: s.announcements,
                          icon: Icons.campaign_outlined,
                          colors: (scheme.tertiaryContainer, scheme.onTertiaryContainer),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab({required this.adminId});

  final String adminId;

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _query = '';
  UserRole? _role;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider);
    final q = _query.trim().toLowerCase();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Nom ou e-mail',
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final role in <UserRole?>[null, ...UserRole.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(_roleIcon(role), size: 18),
                        label: Text(role?.label ?? 'Tous'),
                        selected: _role == role,
                        showCheckmark: false,
                        selectedColor: _roleColors(scheme, role).$1,
                        labelStyle: TextStyle(
                          color: _role == role ? _roleColors(scheme, role).$2 : null,
                        ),
                        onSelected: (_) => setState(() => _role = role),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueWidget(
                value: users,
                onRetry: () => ref.invalidate(allUsersProvider),
                data: (list) {
                  final visible = list
                      .where((u) => _role == null || u.role == _role)
                      .where((u) =>
                          q.isEmpty ||
                          u.displayName.toLowerCase().contains(q) ||
                          u.email.toLowerCase().contains(q))
                      .toList();
                  final count = visible.length;
                  final countText = count == 0
                      ? 'Aucun résultat'
                      : '$count utilisateur${count > 1 ? 's' : ''}';
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              countText,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? const EmptyState(
                                icon: Icons.search_off,
                                message: 'Aucun utilisateur ne correspond à votre recherche.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: visible.length,
                                itemBuilder: (_, i) {
                                  final u = visible[i];
                                  final isSelf = u.id == widget.adminId;
                                  return _UserCard(
                                    user: u,
                                    isSelf: isSelf,
                                    onTap: isSelf
                                        ? null
                                        : () => showDialog<void>(
                                              context: context,
                                              builder: (_) => _RoleDialog(user: u),
                                            ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isSelf, this.onTap});

  final AppUser user;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                UserAvatar(name: user.displayName),
                Gaps.md,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                      Text(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      if (user.university.isNotEmpty)
                        Text(user.university,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      Gaps.xs,
                      RoleBadge(role: user.role),
                    ],
                  ),
                ),
                Gaps.sm,
                if (isSelf)
                  Text('Vous',
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary))
                else
                  Tooltip(
                    message: 'Changer le rôle',
                    child: Icon(Icons.manage_accounts, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleDialog extends ConsumerStatefulWidget {
  const _RoleDialog({required this.user});

  final AppUser user;

  @override
  ConsumerState<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends ConsumerState<_RoleDialog> {
  late UserRole _role = widget.user.role;
  late String? _partnerId = widget.user.partnerId;
  bool _saving = false;

  Future<void> _save() async {
    if (_role == widget.user.role && _partnerId == widget.user.partnerId) {
      Navigator.pop(context);
      return;
    }
    if (_role != widget.user.role) {
      final confirmed = await confirmDialog(
        context,
        title: 'Changer le rôle ?',
        message: '${widget.user.displayName} passera de '
            '« ${widget.user.role.label} » à « ${_role.label} ».',
        confirmLabel: 'Confirmer',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _saving = true);
    final ok = await guard(
      () => ref
          .read(userRepositoryProvider)
          .setRole(widget.user.id, _role, partnerId: _partnerId),
      success: 'Rôle de ${widget.user.displayName} mis à jour',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(partnersProvider).valueOrNull ?? const [];
    final partnerValid = partners.any((p) => p.id == _partnerId);
    final canSave = !_saving && (_role != UserRole.partner || partnerValid);

    return AlertDialog(
      title: Text(widget.user.displayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.user.email),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: [
              for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => setState(() => _role = r ?? _role),
          ),
          if (_role == UserRole.partner) ...[
            const SizedBox(height: 16),
            partners.isEmpty
                ? const Text("Référencez d'abord une université partenaire.")
                : DropdownButtonFormField<String>(
                    initialValue: partnerValid ? _partnerId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Université représentée'),
                    items: [
                      for (final p in partners)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (id) => setState(() => _partnerId = id),
                  ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: canSave ? _save : null, child: const Text('Enregistrer')),
      ],
    );
  }
}
