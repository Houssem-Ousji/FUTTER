import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_user.dart';

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider)));

final userProvider = StreamProvider.family<AppUser?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchUser(uid),
);

final allUsersProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(userRepositoryProvider).watchAll(),
);

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<AppUser?> watchUser(String uid) =>
      _users.doc(uid).snapshots().map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  Stream<List<AppUser>> watchAll() => _users
      .orderBy('displayName')
      .limit(500)
      .snapshots()
      .map((snap) => snap.docs.map(AppUser.fromDoc).toList());

  Future<void> createProfile({
    required String uid,
    required String displayName,
    required String email,
    required UserRole role,
    required String university,
    required String fieldOfStudy,
  }) =>
      _users.doc(uid).set({
        'displayName': displayName,
        'email': email,
        'role': role.name,
        'bio': '',
        'university': university,
        'fieldOfStudy': fieldOfStudy,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateProfile(
    String uid, {
    required String displayName,
    required String bio,
    required String university,
    required String fieldOfStudy,
  }) =>
      _users.doc(uid).update({
        'displayName': displayName,
        'bio': bio,
        'university': university,
        'fieldOfStudy': fieldOfStudy,
      });

  /// Réservé aux administrateurs (contrôlé par les règles Firestore).
  Future<void> setRole(String uid, UserRole role, {String? partnerId}) =>
      _users.doc(uid).update({
        'role': role.name,
        'partnerId': role == UserRole.partner ? partnerId : null,
      });

  /// Jetons FCM stockés en sous-collection privée (lisible par son seul
  /// propriétaire et par les Cloud Functions).
  Future<void> saveToken(String uid, String token) => _users
      .doc(uid)
      .collection('tokens')
      .doc(token)
      .set({'updatedAt': FieldValue.serverTimestamp()});

  Future<void> deleteToken(String uid, String token) =>
      _users.doc(uid).collection('tokens').doc(token).delete();
}
