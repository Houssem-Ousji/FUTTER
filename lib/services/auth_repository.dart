import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_user.dart';
import 'user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(userRepositoryProvider)),
);

class AuthRepository {
  AuthRepository(this._auth, this._users);

  final FirebaseAuth _auth;
  final UserRepository _users;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    required UserRole role,
    required String university,
    required String fieldOfStudy,
  }) async {
    final credential =
        await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = credential.user!;
    await user.updateDisplayName(displayName);
    await _users.createProfile(
      uid: user.uid,
      displayName: displayName,
      email: user.email ?? email.trim(),
      role: role,
      university: university,
      fieldOfStudy: fieldOfStudy,
    );
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}
