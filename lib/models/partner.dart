import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

/// Université partenaire.
class Partner {
  const Partner({
    required this.id,
    required this.name,
    this.country = '',
    this.city = '',
    this.website = '',
    this.contactEmail = '',
    this.description = '',
  });

  factory Partner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Partner(
      id: doc.id,
      name: stringFrom(data['name']),
      country: stringFrom(data['country']),
      city: stringFrom(data['city']),
      website: stringFrom(data['website']),
      contactEmail: stringFrom(data['contactEmail']),
      description: stringFrom(data['description']),
    );
  }

  final String id;
  final String name;
  final String country;
  final String city;
  final String website;
  final String contactEmail;
  final String description;

  String get location => [city, country].where((s) => s.isNotEmpty).join(', ');

  Map<String, dynamic> toMap() => {
        'name': name,
        'country': country,
        'city': city,
        'website': website,
        'contactEmail': contactEmail,
        'description': description,
      };
}

enum AnnouncementType {
  announcement('Annonce'),
  event('Événement'),
  opportunity('Opportunité');

  const AnnouncementType(this.label);
  final String label;

  static AnnouncementType fromName(Object? name) =>
      enumFrom(AnnouncementType.values, name, AnnouncementType.announcement);
}

/// Annonce, événement ou opportunité (stage, bourse, mobilité…)
/// publié par une université partenaire.
class Announcement {
  const Announcement({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.type,
    required this.title,
    required this.description,
    required this.authorId,
    required this.createdAt,
    this.eventDate,
    this.link = '',
  });

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Announcement(
      id: doc.id,
      partnerId: stringFrom(data['partnerId']),
      partnerName: stringFrom(data['partnerName']),
      type: AnnouncementType.fromName(data['type']),
      title: stringFrom(data['title']),
      description: stringFrom(data['description']),
      authorId: stringFrom(data['authorId']),
      createdAt: dateFrom(data['createdAt']),
      eventDate: optionalDateFrom(data['eventDate']),
      link: stringFrom(data['link']),
    );
  }

  final String id;
  final String partnerId;
  final String partnerName;
  final AnnouncementType type;
  final String title;
  final String description;
  final String authorId;
  final DateTime createdAt;

  /// Date de l'événement ou date limite de candidature.
  final DateTime? eventDate;
  final String link;
}
