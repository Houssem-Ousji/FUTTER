import 'package:cloud_firestore/cloud_firestore.dart';

/// Les horodatages serveur valent null tant que l'écriture locale n'est pas
/// confirmée : on affiche alors l'heure courante.
DateTime dateFrom(Object? value) => value is Timestamp ? value.toDate() : DateTime.now();

DateTime? optionalDateFrom(Object? value) => value is Timestamp ? value.toDate() : null;

int intFrom(Object? value) => value is num ? value.toInt() : 0;

String stringFrom(Object? value) => value is String ? value : '';

List<String> stringListFrom(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

T enumFrom<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);
