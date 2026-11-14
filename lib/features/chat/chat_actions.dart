import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/app_user.dart';
import '../../services/chat_repository.dart';

/// Ouvre (ou crée) la conversation privée avec [other].
Future<void> startConversation(
  BuildContext context,
  WidgetRef ref,
  AppUser other, {
  bool replace = false,
}) async {
  final me = ref.read(currentUserProvider).valueOrNull;
  if (me == null || me.id == other.id) return;
  String? id;
  final ok = await guard(() async {
    id = await ref.read(chatRepositoryProvider).openConversation(me, other);
  });
  if (!ok || id == null || !context.mounted) return;
  if (replace) {
    context.pushReplacement('/chat/$id');
  } else {
    context.push('/chat/$id');
  }
}
