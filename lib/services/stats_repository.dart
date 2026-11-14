import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_user.dart';
import '../models/article.dart';

class PlatformStats {
  const PlatformStats({
    required this.usersByRole,
    required this.articlesByCategory,
    required this.partners,
    required this.announcements,
  });

  final Map<UserRole, int> usersByRole;
  final Map<ArticleCategory, int> articlesByCategory;
  final int partners;
  final int announcements;

  int get totalUsers => usersByRole.values.fold(0, (a, b) => a + b);
  int get totalArticles => articlesByCategory.values.fold(0, (a, b) => a + b);
}

/// Statistiques globales (tableau de bord administrateur), calculées avec
/// des requêtes d'agrégation count() : aucun document n'est téléchargé.
final platformStatsProvider = FutureProvider.autoDispose<PlatformStats>((ref) async {
  final db = ref.watch(firestoreProvider);

  Future<int> count(Query<Map<String, dynamic>> query) async =>
      (await query.count().get()).count ?? 0;

  final users = db.collection('users');
  final articles = db.collection('articles');

  final results = await Future.wait([
    for (final role in UserRole.values) count(users.where('role', isEqualTo: role.name)),
    for (final c in ArticleCategory.values) count(articles.where('category', isEqualTo: c.name)),
    count(db.collection('partners')),
    count(db.collection('announcements')),
  ]);

  final roles = UserRole.values;
  final categories = ArticleCategory.values;
  return PlatformStats(
    usersByRole: {for (var i = 0; i < roles.length; i++) roles[i]: results[i]},
    articlesByCategory: {
      for (var i = 0; i < categories.length; i++) categories[i]: results[roles.length + i],
    },
    partners: results[roles.length + categories.length],
    announcements: results[roles.length + categories.length + 1],
  );
});
