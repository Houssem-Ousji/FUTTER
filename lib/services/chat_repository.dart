import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_user.dart';
import '../models/chat.dart';

/// Dépend de l'utilisateur connecté : les flux Firestore sont recréés à chaque
/// connexion/déconnexion (sinon une erreur permission-denied reste en cache).
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  ref.watch(currentUidProvider);
  return ChatRepository(ref.watch(firestoreProvider));
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchConversations(uid);
});

final conversationProvider = StreamProvider.family<Conversation?, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).watchConversation(id),
);

final messagesProvider = StreamProvider.family<List<Message>, String>(
  (ref, conversationId) => ref.watch(chatRepositoryProvider).watchMessages(conversationId),
);

final unreadConversationsProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? const [];
  if (uid == null) return 0;
  return conversations.where((c) => c.isUnreadFor(uid)).length;
});

class ChatRepository {
  ChatRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  /// Identifiant déterministe d'une conversation privée : les deux uid triés.
  /// Les règles Firestore s'appuient sur ce format.
  static String conversationId(String a, String b) => ([a, b]..sort()).join('_');

  Stream<List<Conversation>> watchConversations(String uid) => _conversations
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(Conversation.fromDoc).toList());

  Stream<Conversation?> watchConversation(String id) => _conversations
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Conversation.fromDoc(doc) : null);

  Stream<List<Message>> watchMessages(String conversationId) => _conversations
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs.map(Message.fromDoc).toList());

  /// Renvoie l'identifiant de la conversation, créée si nécessaire.
  Future<String> openConversation(AppUser me, AppUser other) async {
    final id = conversationId(me.id, other.id);
    final ref = _conversations.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': id.split('_'),
        'names': {me.id: me.displayName, other.id: other.displayName},
        'lastMessage': '',
        'lastSenderId': null,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'readBy': [me.id],
      });
    }
    return id;
  }

  Future<void> sendMessage(String conversationId, String senderId, String text) {
    final conversation = _conversations.doc(conversationId);
    final batch = _db.batch()
      ..set(conversation.collection('messages').doc(), {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(conversation, {
        'lastMessage': text,
        'lastSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'readBy': [senderId],
      });
    return batch.commit();
  }

  Future<void> markRead(String conversationId, String uid) =>
      _conversations.doc(conversationId).update({
        'readBy': FieldValue.arrayUnion([uid]),
      });
}
