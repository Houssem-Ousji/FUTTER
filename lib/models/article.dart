import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';
import 'model_utils.dart';

enum ArticleCategory {
  article('Article', 'Article'),
  research('Travail de recherche', 'Recherche'),
  courseSummary('Résumé de cours', 'Résumé'),
  resource('Ressource pédagogique', 'Ressource');

  const ArticleCategory(this.label, this.shortLabel);
  final String label;
  final String shortLabel;

  static ArticleCategory fromName(Object? name) =>
      enumFrom(ArticleCategory.values, name, ArticleCategory.article);
}

enum ReactionType {
  like('👍', "J'aime"),
  useful('💡', 'Utile'),
  bravo('👏', 'Bravo');

  const ReactionType(this.emoji, this.label);
  final String emoji;
  final String label;

  static ReactionType? tryParse(Object? name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// Champs modifiables d'une publication.
class ArticleDraft {
  const ArticleDraft({
    required this.title,
    required this.content,
    required this.category,
    this.tags = const [],
    this.attachmentUrl = '',
  });

  final String title;
  final String content;
  final ArticleCategory category;
  final List<String> tags;
  final String attachmentUrl;

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'category': category.name,
        'tags': tags,
        'attachmentUrl': attachmentUrl,
      };
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.attachmentUrl = '',
    this.commentCount = 0,
    this.reactions = const {},
  });

  factory Article.fromMap(String id, Map<String, dynamic> data) {
    final rawReactions = data['reactions'];
    return Article(
      id: id,
      title: stringFrom(data['title']),
      content: stringFrom(data['content']),
      category: ArticleCategory.fromName(data['category']),
      authorId: stringFrom(data['authorId']),
      authorName: stringFrom(data['authorName']),
      authorRole: UserRole.fromName(data['authorRole']),
      createdAt: dateFrom(data['createdAt']),
      updatedAt: optionalDateFrom(data['updatedAt']),
      tags: stringListFrom(data['tags']),
      attachmentUrl: stringFrom(data['attachmentUrl']),
      commentCount: intFrom(data['commentCount']),
      reactions: rawReactions is Map
          ? rawReactions.map((key, value) => MapEntry(key.toString(), intFrom(value)))
          : const {},
    );
  }

  factory Article.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Article.fromMap(doc.id, doc.data() ?? const {});

  final String id;
  final String title;
  final String content;
  final ArticleCategory category;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final String attachmentUrl;
  final int commentCount;

  /// Nombre de réactions par type (clé = [ReactionType.name]).
  final Map<String, int> reactions;

  int get reactionTotal => reactions.values.fold(0, (total, n) => total + n);

  int reactionCount(ReactionType type) => reactions[type.name] ?? 0;

  bool get wasEdited =>
      updatedAt != null && updatedAt!.difference(createdAt).inMinutes >= 1;

  ArticleDraft get draft => ArticleDraft(
        title: title,
        content: content,
        category: category,
        tags: tags,
        attachmentUrl: attachmentUrl,
      );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        authorName.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Comment(
      id: doc.id,
      authorId: stringFrom(data['authorId']),
      authorName: stringFrom(data['authorName']),
      authorRole: UserRole.fromName(data['authorRole']),
      text: stringFrom(data['text']),
      createdAt: dateFrom(data['createdAt']),
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final String text;
  final DateTime createdAt;
}
