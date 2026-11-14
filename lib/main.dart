import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/emulators.dart';
import 'firebase_options.dart';

FirebaseOptions get _firebaseOptions =>
    useEmulators ? demoFirebaseOptions : DefaultFirebaseOptions.currentPlatform;

/// Traitement des messages push reçus quand l'application est en arrière-plan.
/// Les notifications sont affichées automatiquement par le système.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: _firebaseOptions);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _firebaseOptions);
  if (useEmulators) await connectToEmulators();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }
  await initializeDateFormatting('fr_FR');
  runApp(const ProviderScope(child: EduShareApp()));
}
