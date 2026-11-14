import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Mode développement local : `flutter run --dart-define=USE_EMULATORS=true`.
/// L'application se connecte alors à la Firebase Emulator Suite
/// (`firebase emulators:start`) au lieu d'un vrai projet Firebase.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// Hôte des émulateurs. Depuis un émulateur Android : 10.0.2.2.
const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

/// Options fictives : un projet « demo-* » n'existe que dans les émulateurs.
const demoFirebaseOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-edushare',
);

Future<void> connectToEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
}
