import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

enum UserRole {
  student('Étudiant'),
  teacher('Enseignant'),
  admin('Administrateur'),
  partner('Partenaire');

  const UserRole(this.label);
  final String label;

  /// Rôles qu'un utilisateur peut choisir lui-même à l'inscription.
  /// Les rôles administrateur et partenaire sont attribués par un administrateur.
  static const selfAssignable = [UserRole.student, UserRole.teacher];

  static UserRole fromName(Object? name) => enumFrom(UserRole.values, name, UserRole.student);
}

/// Compteurs d'activité, maintenus par les Cloud Functions.
class UserStats {
  const UserStats({this.articles = 0, this.comments = 0, this.reactionsReceived = 0});

  factory UserStats.fromMap(Object? map) {
    final m = map is Map ? map : const {};
    return UserStats(
      articles: intFrom(m['articles']),
      comments: intFrom(m['comments']),
      reactionsReceived: intFrom(m['reactionsReceived']),
    );
  }

  final int articles;
  final int comments;
  final int reactionsReceived;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.createdAt,
    this.bio = '',
    this.university = '',
    this.fieldOfStudy = '',
    this.partnerId,
    this.stats = const UserStats(),
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> data) => AppUser(
        id: id,
        displayName: stringFrom(data['displayName']),
        email: stringFrom(data['email']),
        role: UserRole.fromName(data['role']),
        createdAt: dateFrom(data['createdAt']),
        bio: stringFrom(data['bio']),
        university: stringFrom(data['university']),
        fieldOfStudy: stringFrom(data['fieldOfStudy']),
        partnerId: data['partnerId'] as String?,
        stats: UserStats.fromMap(data['stats']),
      );

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data() ?? const {});

  final String id;
  final String displayName;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String bio;
  final String university;
  final String fieldOfStudy;

  /// Université partenaire représentée (rôle partenaire uniquement).
  final String? partnerId;
  final UserStats stats;

  bool get isAdmin => role == UserRole.admin;

  /// Peut publier des annonces au nom de l'université [partnerId].
  bool canPublishFor(String partnerId) =>
      isAdmin || (role == UserRole.partner && this.partnerId == partnerId);

  String get subtitle => [
        role.label,
        if (university.isNotEmpty) university,
        if (fieldOfStudy.isNotEmpty) fieldOfStudy,
      ].join(' · ');
}
