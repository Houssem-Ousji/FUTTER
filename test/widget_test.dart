// Tests unitaires des modèles et utilitaires (sans Firebase).
// Ce fichier porte le nom généré par `flutter create` pour que la commande
// ne le remplace pas par le test par défaut, qui ne compilerait pas.
import 'package:edushare/core/formatters.dart';
import 'package:edushare/core/validators.dart';
import 'package:edushare/models/app_user.dart';
import 'package:edushare/models/article.dart';
import 'package:edushare/services/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('identifiant de conversation indépendant de l\'ordre', () {
    expect(ChatRepository.conversationId('b', 'a'), 'a_b');
    expect(ChatRepository.conversationId('a', 'b'), 'a_b');
  });

  test('rôle inconnu → étudiant', () {
    expect(UserRole.fromName('teacher'), UserRole.teacher);
    expect(UserRole.fromName('hacker'), UserRole.student);
    expect(UserRole.fromName(null), UserRole.student);
  });

  test('droits de publication des annonces', () {
    AppUser user(UserRole role, [String? partnerId]) => AppUser(
          id: 'u',
          displayName: 'Test',
          email: 't@x.fr',
          role: role,
          createdAt: DateTime(2026),
          partnerId: partnerId,
        );
    expect(user(UserRole.admin).canPublishFor('p1'), isTrue);
    expect(user(UserRole.partner, 'p1').canPublishFor('p1'), isTrue);
    expect(user(UserRole.partner, 'p1').canPublishFor('p2'), isFalse);
    expect(user(UserRole.teacher).canPublishFor('p1'), isFalse);
  });

  test('lecture d\'une publication', () {
    final article = Article.fromMap('a1', {
      'title': 'Algèbre linéaire',
      'content': 'Résumé',
      'category': 'courseSummary',
      'authorName': 'Sami',
      'tags': ['maths', 42],
      'reactions': {'like': 2, 'useful': 3},
    });
    expect(article.category, ArticleCategory.courseSummary);
    expect(article.tags, ['maths']);
    expect(article.reactionTotal, 5);
    expect(article.reactionCount(ReactionType.bravo), 0);
    expect(article.matches('ALGÈBRE'), isTrue);
    expect(article.matches('maths'), isTrue);
    expect(article.matches('physique'), isFalse);
  });

  test('durées relatives', () {
    final now = DateTime(2026, 11, 6, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), "à l'instant");
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), 'il y a 5 min');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), 'il y a 3 h');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), 'il y a 2 j');
  });

  test('validateurs', () {
    expect(validateEmail('a@b.fr'), isNull);
    expect(validateEmail('ab.fr'), isNotNull);
    expect(validateOptionalUrl(''), isNull);
    expect(validateOptionalUrl('https://univ.fr/doc.pdf'), isNull);
    expect(validateOptionalUrl('ftp://x'), isNotNull);
    expect(validatePassword('1234567'), isNotNull);
  });
}
