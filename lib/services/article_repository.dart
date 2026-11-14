import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_user.dart';
import '../models/article.dart';

/// Dépend de l'utilisateur connecté : les flux Firestore sont recréés à chaque
/// connexion/déconnexion (sinon une erreur permission-denied reste en cache).
final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  ref.watch(currentUidProvider);
  return ArticleRepository(ref.watch(firestoreProvider));
});

/// Fil des publications, filtré par catégorie (null = toutes).
final articlesProvider = StreamProvider.family<List<Article>, ArticleCategory?>(
  (ref, category) => ref.watch(articleRepositoryProvider).watchArticles(category: category),
);

final articleProvider = StreamProvider.family<Article?, String>(
  (ref, id) => ref.watch(articleRepositoryProvider).watchArticle(id),
);

final articlesByAuthorProvider = StreamProvider.family<List<Article>, String>(
  (ref, authorId) => ref.watch(articleRepositoryProvider).watchByAuthor(authorId),
);

final commentsProvider = StreamProvider.family<List<Comment>, String>(
  (ref, articleId) => ref.watch(articleRepositoryProvider).watchComments(articleId),
);

/// Réaction de l'utilisateur connecté sur une publication.
final myReactionProvider = StreamProvider.family<ReactionType?, String>((ref, articleId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(articleRepositoryProvider).watchReaction(articleId, uid);
});

class ArticleRepository {
  ArticleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _articles => _db.collection('articles');

  Stream<List<Article>> watchArticles({ArticleCategory? category}) {
    Query<Map<String, dynamic>> query = _articles;
    if (category != null) query = query.where('category', isEqualTo: category.name);
    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(Article.fromDoc).toList());
  }

  Stream<Article?> watchArticle(String id) =>
      _articles.doc(id).snapshots().map((doc) => doc.exists ? Article.fromDoc(doc) : null);

  Future<Article?> getArticle(String id) async {
    final doc = await _articles.doc(id).get();
    return doc.exists ? Article.fromDoc(doc) : null;
  }

  Stream<List<Article>> watchByAuthor(String authorId) => _articles
      .where('authorId', isEqualTo: authorId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(Article.fromDoc).toList());

  Future<String> create(AppUser author, ArticleDraft draft) async {
    final ref = await _articles.add({
      ...draft.toMap(),
      'authorId': author.id,
      'authorName': author.displayName,
      'authorRole': author.role.name,
      'commentCount': 0,
      'reactions': <String, int>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, ArticleDraft draft) => _articles.doc(id).update({
        ...draft.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Les commentaires et réactions sont supprimés par une Cloud Function.
  Future<void> delete(String id) => _articles.doc(id).delete();

  // --- Commentaires ---

  Stream<List<Comment>> watchComments(String articleId) => _articles
      .doc(articleId)
      .collection('comments')
      .orderBy('createdAt')
      .limit(300)
      .snapshots()
      .map((snap) => snap.docs.map(Comment.fromDoc).toList());

  Future<void> addComment(String articleId, AppUser author, String text) =>
      _articles.doc(articleId).collection('comments').add({
        'authorId': author.id,
        'authorName': author.displayName,
        'authorRole': author.role.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteComment(String articleId, String commentId) =>
      _articles.doc(articleId).collection('comments').doc(commentId).delete();

  // --- Réactions (une par utilisateur, document = uid) ---

  Stream<ReactionType?> watchReaction(String articleId, String uid) => _articles
      .doc(articleId)
      .collection('reactions')
      .doc(uid)
      .snapshots()
      .map((doc) => ReactionType.tryParse(doc.data()?['type']));

  /// [type] null retire la réaction.
  Future<void> setReaction(String articleId, String uid, ReactionType? type) {
    final ref = _articles.doc(articleId).collection('reactions').doc(uid);
    if (type == null) return ref.delete();
    return ref.set({'type': type.name, 'createdAt': FieldValue.serverTimestamp()});
  }
}
