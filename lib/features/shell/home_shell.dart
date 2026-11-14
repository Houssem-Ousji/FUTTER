import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../services/chat_repository.dart';
import '../../services/notification_repository.dart';
import '../../services/push_service.dart';

/// Barre de navigation principale (5 onglets) et activation des
/// notifications push pour l'utilisateur connecté.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(currentUidProvider, (_, uid) {
      if (uid != null) ref.read(pushServiceProvider).init(uid);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final unreadChats = ref.watch(unreadConversationsProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final shell = widget.navigationShell;

    void onSelect(int index) =>
        shell.goBranch(index, initialLocation: index == shell.currentIndex);

    final items = <({IconData icon, IconData selected, String label, int badge})>[
      (icon: Icons.article_outlined, selected: Icons.article, label: 'Contenus', badge: 0),
      (
        icon: Icons.account_balance_outlined,
        selected: Icons.account_balance,
        label: 'Partenaires',
        badge: 0
      ),
      (
        icon: Icons.chat_bubble_outline,
        selected: Icons.chat_bubble,
        label: 'Messages',
        badge: unreadChats
      ),
      (
        icon: Icons.notifications_outlined,
        selected: Icons.notifications,
        label: 'Alertes',
        badge: unreadNotifications
      ),
      (icon: Icons.person_outline, selected: Icons.person, label: 'Profil', badge: 0),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              minWidth: 88,
              backgroundColor: scheme.surfaceContainer,
              indicatorColor: scheme.primaryContainer,
              selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
              selectedLabelTextStyle:
                  TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
              unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
              leading: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Semantics(
                  header: true,
                  label: 'EduShare',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.school, color: scheme.onPrimary),
                      ),
                      Gaps.xs,
                      Text(
                        'EduShare',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              destinations: [
                for (final it in items)
                  NavigationRailDestination(
                    icon: _badge(it.badge, Icon(it.icon), it.label),
                    selectedIcon: _badge(it.badge, Icon(it.selected), it.label),
                    label: Text(it.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final it in items)
            NavigationDestination(
              icon: _badge(it.badge, Icon(it.icon), it.label),
              selectedIcon: _badge(it.badge, Icon(it.selected), it.label),
              label: it.label,
            ),
        ],
      ),
    );
  }

  Widget _badge(int count, Widget icon, String label) {
    final badge = Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
    if (count <= 0) return badge;
    final plural = count > 1;
    final text = label == 'Messages'
        ? '$count ${plural ? 'messages non lus' : 'message non lu'}'
        : '$count ${plural ? 'alertes non lues' : 'alerte non lue'}';
    return Semantics(label: text, child: badge);
  }
}
