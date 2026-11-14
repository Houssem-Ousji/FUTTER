import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watch(uid);
});

final unreadNotificationsProvider = Provider<int>(
  (ref) => (ref.watch(notificationsProvider).valueOrNull ?? const [])
      .where((n) => !n.read)
      .length,
);

class NotificationRepository {
  NotificationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watch(String uid) => _collection(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());

  Future<void> markRead(String uid, String id) =>
      _collection(uid).doc(id).update({'read': true});

  Future<void> markAllRead(String uid, Iterable<AppNotification> notifications) {
    final batch = _db.batch();
    for (final n in notifications.where((n) => !n.read)) {
      batch.update(_collection(uid).doc(n.id), {'read': true});
    }
    return batch.commit();
  }

  Future<void> delete(String uid, String id) => _collection(uid).doc(id).delete();
}
