import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.names,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastSenderId,
    this.readBy = const [],
  });

  factory Conversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawNames = data['names'];
    return Conversation(
      id: doc.id,
      participants: stringListFrom(data['participants']),
      names: rawNames is Map
          ? rawNames.map((key, value) => MapEntry(key.toString(), stringFrom(value)))
          : const {},
      lastMessage: stringFrom(data['lastMessage']),
      lastMessageAt: dateFrom(data['lastMessageAt']),
      lastSenderId: data['lastSenderId'] as String?,
      readBy: stringListFrom(data['readBy']),
    );
  }

  final String id;
  final List<String> participants;

  /// Noms affichés, indexés par identifiant d'utilisateur.
  final Map<String, String> names;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastSenderId;

  /// Utilisateurs ayant lu le dernier message.
  final List<String> readBy;

  String otherId(String me) => participants.firstWhere((p) => p != me, orElse: () => me);

  String otherName(String me) => names[otherId(me)] ?? 'Utilisateur';

  bool isUnreadFor(String uid) => lastSenderId != null && !readBy.contains(uid);
}

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Message(
      id: doc.id,
      senderId: stringFrom(data['senderId']),
      text: stringFrom(data['text']),
      createdAt: dateFrom(data['createdAt']),
    );
  }

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
}
