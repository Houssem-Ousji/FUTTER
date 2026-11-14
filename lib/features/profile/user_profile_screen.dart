import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/user_repository.dart';
import '../../widgets/common.dart';
import 'profile_view.dart';

/// Profil public d'un autre membre.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(userId));
    final isMe = ref.watch(currentUidProvider) == userId;
    return Scaffold(
      appBar: AppBar(title: Text(user.valueOrNull?.displayName ?? 'Profil')),
      body: AsyncValueWidget(
        value: user,
        data: (u) => u == null
            ? const EmptyState(icon: Icons.person_off_outlined, message: 'Membre introuvable.')
            : ProfileView(user: u, isMe: isMe),
      ),
    );
  }
}
