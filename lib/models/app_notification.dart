import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

/// Notification in-app, créée par les Cloud Functions
/// dans users/{uid}/notifications.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route = '',
    this.read = false,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      type: stringFrom(data['type']),
      title: stringFrom(data['title']),
      body: stringFrom(data['body']),
      createdAt: dateFrom(data['createdAt']),
      route: stringFrom(data['route']),
      read: data['read'] == true,
    );
  }

  /// comment, reaction…
  final String type;
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Écran à ouvrir au toucher (ex. /article/abc).
  final String route;
  final bool read;
}
