import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/app_user.dart';
import '../models/partner.dart';

/// Dépend de l'utilisateur connecté : les flux Firestore sont recréés à chaque
/// connexion/déconnexion (sinon une erreur permission-denied reste en cache).
final partnerRepositoryProvider = Provider<PartnerRepository>((ref) {
  ref.watch(currentUidProvider);
  return PartnerRepository(ref.watch(firestoreProvider));
});

final partnersProvider = StreamProvider<List<Partner>>(
  (ref) => ref.watch(partnerRepositoryProvider).watchPartners(),
);

final partnerProvider = StreamProvider.family<Partner?, String>(
  (ref, id) => ref.watch(partnerRepositoryProvider).watchPartner(id),
);

/// Annonces d'une université (ou de toutes si partnerId est null).
final announcementsProvider = StreamProvider.family<List<Announcement>, String?>(
  (ref, partnerId) =>
      ref.watch(partnerRepositoryProvider).watchAnnouncements(partnerId: partnerId),
);

class PartnerRepository {
  PartnerRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _partners => _db.collection('partners');
  CollectionReference<Map<String, dynamic>> get _announcements =>
      _db.collection('announcements');

  Stream<List<Partner>> watchPartners() => _partners
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map(Partner.fromDoc).toList());

  Stream<Partner?> watchPartner(String id) =>
      _partners.doc(id).snapshots().map((doc) => doc.exists ? Partner.fromDoc(doc) : null);

  Future<Partner?> getPartner(String id) async {
    final doc = await _partners.doc(id).get();
    return doc.exists ? Partner.fromDoc(doc) : null;
  }

  /// Crée l'université si [id] est null, sinon la met à jour.
  Future<String> savePartner(Partner partner, {String? id}) async {
    if (id == null) {
      final ref = await _partners.add({
        ...partner.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
    await _partners.doc(id).update(partner.toMap());
    return id;
  }

  /// Les annonces de l'université sont supprimées par une Cloud Function.
  Future<void> deletePartner(String id) => _partners.doc(id).delete();

  Stream<List<Announcement>> watchAnnouncements({String? partnerId}) {
    Query<Map<String, dynamic>> query = _announcements;
    if (partnerId != null) query = query.where('partnerId', isEqualTo: partnerId);
    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(Announcement.fromDoc).toList());
  }

  Future<void> createAnnouncement({
    required Partner partner,
    required AppUser author,
    required AnnouncementType type,
    required String title,
    required String description,
    DateTime? eventDate,
    String link = '',
  }) =>
      _announcements.add({
        'partnerId': partner.id,
        'partnerName': partner.name,
        'type': type.name,
        'title': title,
        'description': description,
        'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
        'link': link,
        'authorId': author.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteAnnouncement(String id) => _announcements.doc(id).delete();
}
