import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/router.dart';
import 'user_repository.dart';

/// Sujet FCM auquel tous les appareils sont abonnés pour recevoir les
/// annonces des universités partenaires (envoyées par une Cloud Function).
const announcementsTopic = 'announcements';

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Notifications push : enregistrement du jeton FCM, abonnement aux annonces,
/// affichage au premier plan et navigation au toucher.
///
/// Chaque message envoyé par les Cloud Functions porte dans `data.route`
/// l'écran à ouvrir (ex. /chat/abc, /article/xyz).
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  String? _uid;
  String? _token;

  // Le Web nécessite une clé VAPID et un service worker : non géré ici.
  bool get _supported => !kIsWeb;

  Future<void> init(String uid) async {
    if (!_supported || _uid == uid) return;
    await dispose();
    _uid = uid;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final users = _ref.read(userRepositoryProvider);
      _token = await messaging.getToken();
      if (_token != null) await users.saveToken(uid, _token!);
      _subscriptions.add(messaging.onTokenRefresh.listen((token) async {
        final previous = _token;
        _token = token;
        if (previous != null) await users.deleteToken(uid, previous);
        await users.saveToken(uid, token);
      }));

      await messaging.subscribeToTopic(announcementsTopic);
      _subscriptions
        ..add(FirebaseMessaging.onMessage.listen(_showInApp))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open));

      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('Notifications push indisponibles : $e');
    }
  }

  /// À appeler avant la déconnexion (les règles exigent d'être authentifié
  /// pour supprimer le jeton).
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    if (!_supported || uid == null) return;
    try {
      if (token != null) await _ref.read(userRepositoryProvider).deleteToken(uid, token);
      await FirebaseMessaging.instance.unsubscribeFromTopic(announcementsTopic);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Nettoyage des notifications push impossible : $e');
    }
  }

  void _showInApp(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final text = [notification.title, notification.body]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' — ');
    showMessage(
      text,
      action: _routeOf(message) == null
          ? null
          : SnackBarAction(label: 'Voir', onPressed: () => _open(message)),
    );
  }

  void _open(RemoteMessage message) {
    final route = _routeOf(message);
    if (route != null) _ref.read(routerProvider).push(route);
  }

  String? _routeOf(RemoteMessage message) {
    final route = message.data['route'];
    return route is String && route.startsWith('/') ? route : null;
  }
}
