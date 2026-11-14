import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_screen.dart';
import '../features/articles/article_detail_screen.dart';
import '../features/articles/article_editor_screen.dart';
import '../features/articles/articles_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/conversations_screen.dart';
import '../features/chat/new_chat_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/partners/announcement_editor_screen.dart';
import '../features/partners/partner_detail_screen.dart';
import '../features/partners/partner_editor_screen.dart';
import '../features/partners/partners_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/shell/home_shell.dart';
import 'providers.dart';

const _authRoutes = {'/login', '/register'};

/// Navigation de l'application.
///
/// - Les 5 onglets (contenus, partenaires, messages, alertes, profil) sont
///   dans un [StatefulShellRoute] : chacun conserve son état.
/// - Les écrans de détail et d'édition sont des routes de premier niveau,
///   affichées par-dessus la barre de navigation.
/// - Toutes les routes exigent d'être connecté, sauf /login et /register.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);

  String id(GoRouterState state) => state.pathParameters['id']!;

  final router = GoRouter(
    initialLocation: '/articles',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;
      if (!auth.hasValue && !auth.hasError) {
        return location == '/splash' ? null : '/splash';
      }
      final signedIn = auth.valueOrNull != null;
      if (!signedIn) return _authRoutes.contains(location) ? null : '/login';
      if (_authRoutes.contains(location) || location == '/splash') return '/articles';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/articles', builder: (_, __) => const ArticlesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/partners', builder: (_, __) => const PartnersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chats', builder: (_, __) => const ConversationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      // Publications
      GoRoute(path: '/article/new', builder: (_, __) => const ArticleEditorScreen()),
      GoRoute(
        path: '/article/:id',
        builder: (_, s) => ArticleDetailScreen(articleId: id(s)),
        routes: [
          GoRoute(path: 'edit', builder: (_, s) => ArticleEditorScreen(articleId: id(s))),
        ],
      ),
      // Partenaires
      GoRoute(path: '/partner/new', builder: (_, __) => const PartnerEditorScreen()),
      GoRoute(
        path: '/partner/:id',
        builder: (_, s) => PartnerDetailScreen(partnerId: id(s)),
        routes: [
          GoRoute(path: 'edit', builder: (_, s) => PartnerEditorScreen(partnerId: id(s))),
          GoRoute(
            path: 'announce',
            builder: (_, s) => AnnouncementEditorScreen(partnerId: id(s)),
          ),
        ],
      ),
      // Messagerie
      GoRoute(path: '/chat/new', builder: (_, __) => const NewChatScreen()),
      GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: id(s))),
      // Utilisateurs
      GoRoute(path: '/user/:id', builder: (_, s) => UserProfileScreen(userId: id(s))),
      GoRoute(path: '/me/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
