import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/user_repository.dart';

/// Permet d'afficher des messages (SnackBar) depuis n'importe où, y compris
/// depuis les services (notifications reçues au premier plan).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(String message, {SnackBarAction? action}) {
  scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Identifiant de l'utilisateur connecté (null si déconnecté).
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// Profil Firestore de l'utilisateur connecté (rôle, statistiques…).
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Exécute une action et affiche un message d'erreur compréhensible en cas
/// d'échec. Renvoie true si l'action a réussi.
Future<bool> guard(Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null) showMessage(success);
    return true;
  } on FirebaseAuthException catch (e) {
    showMessage(authErrorMessage(e));
  } on FirebaseException catch (e) {
    showMessage(e.code == 'permission-denied'
        ? "Vous n'avez pas les droits pour effectuer cette action."
        : 'Erreur : ${e.message ?? e.code}');
  } catch (e) {
    showMessage('Erreur : $e');
  }
  return false;
}

String authErrorMessage(FirebaseAuthException e) => switch (e.code) {
      'invalid-email' => 'Adresse e-mail invalide.',
      'user-disabled' => 'Ce compte a été désactivé.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'E-mail ou mot de passe incorrect.',
      'email-already-in-use' => 'Un compte existe déjà avec cette adresse e-mail.',
      'weak-password' => 'Mot de passe trop faible.',
      'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
      'network-request-failed' => 'Pas de connexion réseau.',
      _ => "Erreur d'authentification (${e.code}).",
    };
