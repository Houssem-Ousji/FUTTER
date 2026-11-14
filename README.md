# EduShare

Application mobile Flutter de partage de connaissances académiques entre étudiants, enseignants et universités partenaires. Backend : Firebase (Auth, Firestore, Cloud Messaging, Cloud Functions).

## Modules

| Module | Fonctionnalités | Code |
|---|---|---|
| Authentification et sécurité | Inscription, connexion, mot de passe oublié ; rôles étudiant, enseignant, administrateur, partenaire ; règles Firestore | `lib/features/auth`, `firestore.rules` |
| Articles et contenus | Publication, modification, suppression ; 4 catégories (article, travail de recherche, résumé de cours, ressource pédagogique) ; recherche ; commentaires ; réactions | `lib/features/articles` |
| Utilisateurs | Profils, statistiques d'activité, graphique sur 6 mois, tableau de bord administrateur (statistiques globales, attribution des rôles) | `lib/features/profile`, `lib/features/admin` |
| Communications | Messagerie privée temps réel, alertes in-app, notifications push | `lib/features/chat`, `lib/features/notifications`, `lib/services/push_service.dart` |
| Partenaires universitaires | Référencement des universités, annonces, événements et opportunités | `lib/features/partners` |

## Architecture

```
lib/
  core/         thème, routeur (go_router), providers Riverpod, formatage, validation
  models/       modèles Firestore
  services/     accès aux données (un repository par collection) + service push
  features/     écrans par module
  widgets/      composants partagés
functions/      Cloud Functions (Node 20)
firestore.rules / firestore.indexes.json
```

Les compteurs (commentaires, réactions, statistiques utilisateur) et les notifications sont écrits uniquement par les Cloud Functions ; les règles Firestore interdisent aux clients de les modifier.

### Modèle de données Firestore

| Collection | Contenu |
|---|---|
| `users/{uid}` | profil, `role`, `partnerId`, `stats` |
| `users/{uid}/tokens/{token}` | jetons FCM (privés) |
| `users/{uid}/notifications` | alertes in-app |
| `articles/{id}` (+ `comments`, `reactions/{uid}`) | publications |
| `conversations/{uidA_uidB}` (+ `messages`) | messagerie privée |
| `partners/{id}` | universités partenaires |
| `announcements/{id}` | annonces, événements, opportunités |

## Mise en route

Prérequis : Flutter 3.35 ou plus récent, Node 20, Firebase CLI (`npm i -g firebase-tools`), FlutterFire CLI (`dart pub global activate flutterfire_cli`).

1. **Générer les dossiers de plateforme** (absents du dépôt) :
   ```
   flutter create . --org com.edushare --platforms android,ios
   ```
   Les fichiers existants (`lib/`, `test/widget_test.dart`) ne sont pas écrasés.
2. **Créer un projet Firebase** et activer Authentication (fournisseur e-mail/mot de passe), Firestore et Cloud Messaging. Les Cloud Functions nécessitent la formule Blaze.
3. **Relier l'application** : `flutterfire configure`. La commande remplace `lib/firebase_options.dart`.
4. **Déployer le backend** :
   ```
   firebase use <id-du-projet>
   cd functions && npm install && cd ..
   firebase deploy --only firestore,functions
   ```
5. **Lancer l'application** : `flutter pub get` puis `flutter run`.
6. **Créer le premier administrateur** : inscrivez-vous dans l'application, puis dans la console Firestore passez le champ `role` de votre document `users/{uid}` à `admin`. Les autres rôles (administrateur, partenaire) s'attribuent ensuite depuis l'écran Administration (Profil → icône bouclier).

### Notifications push

- iOS : ajoutez la capability *Push Notifications* dans Xcode et téléversez une clé APNs dans la console Firebase.
- Android 13 et plus : l'autorisation est demandée au premier lancement.
- Le Web n'est pas pris en charge pour les notifications push (clé VAPID et service worker non configurés).

## Lancement local (sans compte Firebase)

Prérequis supplémentaire : Java 21 (pour les émulateurs).

```
firebase emulators:start --project demo-edushare        # terminal 1 — UI : http://127.0.0.1:4100
node functions/scripts/seed.js                           # données de démo (une seule fois)
flutter run -d chrome --dart-define=USE_EMULATORS=true   # terminal 2
```

Comptes de démo, mot de passe `edushare123` : `admin@`, `etudiant@`, `enseignant@`, `partenaire@edushare.dev`.
Les données sont perdues à l'arrêt des émulateurs. Les push sont seulement journalisés dans la console des émulateurs.
Depuis un émulateur Android, ajoutez `--dart-define=EMULATOR_HOST=10.0.2.2`.

## Rôles et droits

| Action | Étudiant | Enseignant | Partenaire | Admin |
|---|:-:|:-:|:-:|:-:|
| Publier, commenter, réagir, discuter | ✓ | ✓ | ✓ | ✓ |
| Modifier sa publication | ✓ | ✓ | ✓ | ✓ |
| Supprimer n'importe quelle publication ou commentaire | | | | ✓ |
| Supprimer un commentaire sur sa publication | ✓ | ✓ | ✓ | ✓ |
| Publier une annonce pour son université | | | ✓ | ✓ |
| Référencer une université, attribuer les rôles | | | | ✓ |

À l'inscription, seuls les rôles étudiant et enseignant peuvent être choisis.

## Tests

```
flutter test
```

## Limites connues

- Pas de stockage de fichiers : un document se joint par lien (aucune dépendance Firebase Storage).
- La recherche filtre localement les 100 dernières publications (Firestore n'a pas de recherche plein texte).
- Le nom d'auteur est copié dans chaque publication : un changement de nom ne modifie pas les publications existantes.
- Retirer une université supprime ses annonces et repasse ses représentants au rôle étudiant.
