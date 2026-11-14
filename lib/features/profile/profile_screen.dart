import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../services/auth_repository.dart';
import '../../services/push_service.dart';
import '../../widgets/common.dart';
import 'profile_view.dart';

/// Profil de l'utilisateur connecté.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous ne recevrez plus de notifications sur cet appareil.',
      confirmLabel: 'Se déconnecter',
    );
    if (!confirmed) return;
    await ref.read(pushServiceProvider).dispose();
    await guard(() => ref.read(authRepositoryProvider).signOut());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user.valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Administration',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push('/admin'),
            ),
          if (user.valueOrNull != null)
            IconButton(
              tooltip: 'Modifier le profil',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/me/edit'),
            ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: AsyncValueWidget(
        value: user,
        data: (me) => me == null
            ? const EmptyState(
                icon: Icons.person_off_outlined,
                message: 'Profil introuvable. Déconnectez-vous puis reconnectez-vous.',
              )
            : ProfileView(user: me, isMe: true),
      ),
    );
  }
}
