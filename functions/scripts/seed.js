/**
 * Données de démonstration pour les émulateurs Firebase.
 *
 *   firebase emulators:start --project demo-edushare
 *   node functions/scripts/seed.js            # crée les données si la base est vide
 *   node functions/scripts/seed.js --reset    # efface comptes + données, puis recrée tout
 *
 * Ne s'exécute que contre les émulateurs (refuse sinon).
 * Tous les comptes ont le mot de passe : edushare123
 *
 * Les compteurs (commentaires, réactions, statistiques) et les notifications
 * sont produits par les Cloud Functions : l'émulateur Functions doit tourner.
 */
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const PROJECT = 'demo-edushare';
initializeApp({ projectId: PROJECT });
const auth = getAuth();
const db = getFirestore();
const PASSWORD = 'edushare123';

// key, nom, e-mail, rôle, université, filière, bio
const USERS = [
  ['admin', 'Admin EduShare', 'admin@edushare.dev', 'admin', 'EduShare', '', 'Administration de la plateforme.'],
  ['student', 'Yasmine Ben Ali', 'etudiant@edushare.dev', 'student', 'Université de Tunis', 'Informatique L3', 'Passionnée d\'IA et de traitement du langage. Projet de fin d\'études en cours.'],
  ['teacher', 'Karim Trabelsi', 'enseignant@edushare.dev', 'teacher', 'Université de Tunis', 'Algorithmique', 'Maître de conférences en algorithmique et bases de données.'],
  ['partner', 'Relations internationales Sorbonne', 'partenaire@edushare.dev', 'partner', 'Sorbonne Université', '', 'Bureau des relations internationales de Sorbonne Université.'],
  ['partner2', 'Bureau des échanges Laval', 'partenaire2@edushare.dev', 'partner', 'Université Laval', '', 'Programmes d\'échange en sciences et en génie.'],
  ['omar', 'Omar Gharbi', 'omar@edushare.dev', 'student', 'Université de Tunis', 'Mathématiques appliquées M1', 'Optimisation, statistiques, un peu de Python.'],
  ['salma', 'Salma Khelifi', 'salma@edushare.dev', 'student', 'Université de Sfax', 'Génie logiciel L2', 'Je partage mes fiches de révision.'],
  ['lucas', 'Lucas Martin', 'lucas@edushare.dev', 'student', 'Sorbonne Université', 'Informatique M1', 'Étudiant Erasmus intéressé par la Tunisie.'],
  ['nour', 'Nour Haddad', 'nour@edushare.dev', 'student', 'Université de Carthage', 'Réseaux et télécoms L3', ''],
  ['amel', 'Amel Mansouri', 'amel@edushare.dev', 'teacher', 'Université de Sfax', 'Probabilités et statistiques', 'Enseignante-chercheuse, responsable du master Data Science.'],
  ['pierre', 'Pierre Dubois', 'pierre@edushare.dev', 'teacher', 'Sorbonne Université', 'Systèmes distribués', 'Professeur invité, co-encadre des doubles diplômes.'],
].map(([key, displayName, email, role, university, fieldOfStudy, bio]) => ({
  key, displayName, email, role, university, fieldOfStudy, bio,
}));

const PARTNERS = [
  ['sorbonne', 'Sorbonne Université', 'Paris', 'France', 'https://www.sorbonne-universite.fr', 'international@sorbonne.example', 'Université pluridisciplinaire partenaire : mobilité Erasmus+, doubles diplômes et stages de recherche.'],
  ['laval', 'Université Laval', 'Québec', 'Canada', 'https://www.ulaval.ca', 'echanges@ulaval.example', 'Programmes d\'échange en sciences et en génie, cotutelles de thèse.'],
  ['tum', 'Technische Universität München', 'Munich', 'Allemagne', 'https://www.tum.de', 'incoming@tum.example', 'Université technique de premier plan : ingénierie, informatique et sciences naturelles.'],
  ['polimi', 'Politecnico di Milano', 'Milan', 'Italie', 'https://www.polimi.it', '', 'Architecture, design et ingénierie. Accords Erasmus+ avec les écoles d\'ingénieurs tunisiennes.'],
  ['rabat', 'Université Mohammed V', 'Rabat', 'Maroc', 'https://www.um5.ac.ma', 'ri@um5.example', 'Coopération maghrébine : échanges d\'étudiants et de chercheurs en sciences et lettres.'],
].map(([key, name, city, country, website, contactEmail, description]) => ({
  key, name, city, country, website, contactEmail, description,
}));

const daysAgo = (n) => Timestamp.fromDate(new Date(Date.now() - n * 86400000));
const pause = (ms) => new Promise((r) => setTimeout(r, ms));

async function reset() {
  const base = { method: 'DELETE' };
  const fs = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, base);
  const au = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/accounts`, base);
  if (!fs.ok || !au.ok) throw new Error(`Réinitialisation impossible (Firestore ${fs.status}, Auth ${au.status})`);
  console.log('Émulateurs réinitialisés.');
  await pause(1500); // laisse les Functions finir de traiter les suppressions
}

async function upsertUser(u) {
  try {
    return (await auth.getUserByEmail(u.email)).uid;
  } catch {
    return (await auth.createUser({ email: u.email, password: PASSWORD, displayName: u.displayName })).uid;
  }
}

async function main() {
  if (process.argv.includes('--reset')) await reset();

  const existing = await db.collection('partners').limit(1).get();
  if (!existing.empty) {
    console.log('Données déjà présentes : rien à faire (utiliser --reset pour tout recréer).');
    return;
  }

  const ids = {};
  for (const u of USERS) ids[u.key] = await upsertUser(u);

  // ---------- Universités partenaires ----------
  const pid = {};
  for (const p of PARTNERS) {
    const { key, ...data } = p;
    const ref = await db.collection('partners').add({ ...data, createdAt: FieldValue.serverTimestamp() });
    pid[key] = ref.id;
  }

  // ---------- Profils ----------
  const partnerOf = { partner: 'sorbonne', partner2: 'laval' };
  const joined = { admin: 200, student: 120, teacher: 150, partner: 140, partner2: 100, omar: 95, salma: 80, lucas: 60, nour: 45, amel: 130, pierre: 110 };
  for (const u of USERS) {
    await db.doc(`users/${ids[u.key]}`).set({
      displayName: u.displayName,
      email: u.email,
      role: u.role,
      bio: u.bio,
      university: u.university,
      fieldOfStudy: u.fieldOfStudy,
      createdAt: daysAgo(joined[u.key]),
      ...(partnerOf[u.key] ? { partnerId: pid[partnerOf[u.key]] } : {}),
    });
  }

  const byKey = Object.fromEntries(USERS.map((u) => [u.key, u]));
  const author = (key) => ({ authorId: ids[key], authorName: byKey[key].displayName, authorRole: byKey[key].role });

  // ---------- Publications (étalées sur 6 mois pour le graphique) ----------
  const ARTICLES = [
    ['teacher', 'courseSummary', 'Résumé : complexité des algorithmes de tri', ['algorithmique', 'L2'], 'Tri par insertion : O(n²) dans le pire cas, O(n) si le tableau est presque trié.\nTri fusion : O(n log n) dans tous les cas, mais mémoire supplémentaire O(n).\nTri rapide : O(n log n) en moyenne, O(n²) dans le pire cas ; le choix du pivot est déterminant.', '', 150],
    ['teacher', 'resource', 'Exercices corrigés de bases de données (SQL)', ['SQL', 'BD'], '20 exercices progressifs : sélection, jointures, agrégats, sous-requêtes. Corrigés détaillés en fin de document.', 'https://example.org/sql-exercices.pdf', 128],
    ['amel', 'courseSummary', 'Probabilités : lois usuelles en un coup d\'œil', ['probabilités', 'statistiques', 'L2'], 'Bernoulli, binomiale, Poisson, normale : paramètres, espérance, variance et cas d\'usage typiques. Un tableau récapitulatif et trois exemples résolus.', '', 112],
    ['salma', 'article', 'Git en équipe : branches, revues et conflits', ['git', 'génie logiciel'], 'Notre équipe de quatre a perdu deux jours à cause de conflits de fusion. Voici le flux de travail que nous avons adopté : une branche par fonctionnalité, revue obligatoire, rebase avant fusion.', '', 98],
    ['pierre', 'resource', 'Introduction aux systèmes distribués : support de cours', ['distribué', 'M1', 'cohérence'], 'Théorème CAP, réplication, consensus (Raft). Support de 60 pages avec exemples en Go. Réutilisable pour vos exposés.', 'https://example.org/systemes-distribues.pdf', 84],
    ['omar', 'research', 'Optimisation convexe appliquée à la logistique', ['optimisation', 'recherche', 'Python'], 'Modélisation d\'un problème de tournées de livraison en programmation linéaire en nombres entiers. Comparaison de deux solveurs sur 200 instances ; le temps de résolution est divisé par 3 avec une relaxation bien choisie.', '', 70],
    ['student', 'article', 'Retour d\'expérience : mon premier hackathon', ['hackathon', 'équipe'], '48 heures, 5 personnes, un prototype de plateforme de covoiturage universitaire. Ce que j\'ai appris sur la gestion du temps et sur le travail en équipe.', '', 58],
    ['teacher', 'article', 'Pourquoi apprendre les structures de données en 2027 ?', ['algorithmique', 'carrière'], 'Les bibliothèques font tout, alors pourquoi s\'y attarder ? Parce que choisir la bonne structure change la complexité d\'un problème et réduit les coûts d\'infrastructure.', '', 47],
    ['nour', 'courseSummary', 'Modèle OSI et TCP/IP : fiche de révision', ['réseaux', 'L3'], 'Les 7 couches en une page, avec le rôle de chaque protocole et les ports usuels (HTTP 80, HTTPS 443, SSH 22, DNS 53).', '', 36],
    ['lucas', 'article', 'Erasmus à Tunis : premières impressions', ['erasmus', 'mobilité'], 'Trois semaines après mon arrivée : logement, transports, organisation des cours, et quelques conseils pour les futurs étudiants en échange.', '', 28],
    ['student', 'research', 'Détection de fake news par apprentissage automatique', ['IA', 'NLP', 'PFE'], 'Mon projet de fin d\'études compare trois approches (TF-IDF + régression logistique, LSTM, CamemBERT) sur un corpus francophone de 12 000 articles. CamemBERT atteint 91 % de F1.', '', 18],
    ['amel', 'resource', 'Jeu de données : notes anonymisées pour TP de statistiques', ['statistiques', 'TP', 'données'], 'Un fichier CSV de 1 500 lignes pour s\'exercer à la régression et aux tests d\'hypothèses. Licence libre.', 'https://example.org/notes-anonymisees.csv', 12],
    ['student', 'article', 'Bien préparer ses examens : méthode des répétitions espacées', ['méthodologie'], 'Réviser un peu chaque jour en espaçant les répétitions est plus efficace que de tout relire la veille. Voici mon planning type sur trois semaines…', '', 5],
    ['salma', 'courseSummary', 'Patrons de conception : les 5 que vous utiliserez vraiment', ['POO', 'génie logiciel', 'L2'], 'Singleton, Fabrique, Observateur, Stratégie, Décorateur : une phrase de définition, un exemple concret et le piège à éviter pour chacun.', '', 2],
    ['pierre', 'article', 'Double diplôme Paris–Tunis : ce qu\'il faut savoir', ['mobilité', 'double diplôme'], 'Calendrier, prérequis, équivalences de crédits et financements. Les candidatures s\'ouvrent bientôt ; voici comment préparer un dossier solide.', '', 1],
  ];
  const aid = [];
  for (const [who, category, title, tags, content, attachmentUrl, days] of ARTICLES) {
    const ref = await db.collection('articles').add({
      ...author(who), category, title, tags, content, attachmentUrl,
      commentCount: 0,
      reactions: {},
      createdAt: daysAgo(days),
      updatedAt: daysAgo(days),
    });
    aid.push(ref.id);
    await pause(60); // laisse le trigger onArticleCreated mettre à jour les statistiques
  }

  // ---------- Commentaires : [index article, auteur, texte, jours] ----------
  const COMMENTS = [
    [0, 'student', 'Merci, très clair ! Le tri par tas est-il au programme ?', 2],
    [0, 'omar', 'Pour le tri rapide, un pivot médian de trois valeurs règle presque tous les cas pénibles.', 1.5],
    [0, 'teacher', 'Oui, le tri par tas sera vu au prochain cours, avec une comparaison expérimentale.', 1],
    [1, 'student', 'Les corrigés des jointures externes m\'ont beaucoup aidée.', 20],
    [2, 'omar', 'Le tableau récapitulatif est parfait pour réviser avant l\'examen.', 8],
    [3, 'student', 'Le rebase avant fusion nous a sauvé la mise sur notre projet de génie logiciel.', 10],
    [3, 'teacher', 'Bonne synthèse. Ajoutez une section sur les conventions de messages de commit.', 9],
    [5, 'amel', 'Intéressant. Avez-vous testé la décomposition de Benders sur les grandes instances ?', 14],
    [6, 'salma', 'On se retrouve au prochain hackathon ? Il nous manque un profil front-end.', 6],
    [6, 'teacher', 'Beau parcours, continuez à participer.', 5],
    [9, 'student', 'Bienvenue ! Le quartier de La Marsa est agréable pour se loger.', 3],
    [9, 'pierre', 'Merci pour ce retour, il sera utile aux prochains candidats.', 2],
    [10, 'teacher', 'Beau travail. Pensez à publier votre corpus pour la reproductibilité.', 1],
    [10, 'amel', 'Avez-vous comparé avec un modèle multilingue ? Les résultats seraient instructifs.', 0.8],
    [10, 'omar', 'F1 de 91 %, impressionnant. Quelle taille de lot avez-vous utilisée ?', 0.5],
    [12, 'salma', 'Je vais essayer ce planning dès cette semaine, merci !', 3],
    [12, 'nour', 'La méthode marche très bien avec des cartes mémoire.', 2],
    [13, 'student', 'Le patron Observateur est bien expliqué, merci Salma.', 1],
    [14, 'lucas', 'Très utile, je dépose mon dossier dès l\'ouverture.', 0.5],
  ];
  for (const [i, who, text, days] of COMMENTS) {
    await db.collection(`articles/${aid[i]}/comments`).add({ ...author(who), text, createdAt: daysAgo(days) });
    await pause(60);
  }

  // ---------- Réactions : [index article, utilisateur, type] ----------
  const REACTIONS = [
    [0, 'student', 'useful'], [0, 'omar', 'like'], [0, 'salma', 'useful'], [0, 'nour', 'like'],
    [1, 'student', 'useful'], [1, 'omar', 'useful'],
    [2, 'student', 'useful'], [2, 'omar', 'like'], [2, 'teacher', 'bravo'],
    [3, 'student', 'like'], [3, 'teacher', 'bravo'],
    [4, 'student', 'useful'], [4, 'lucas', 'useful'],
    [5, 'amel', 'bravo'], [5, 'teacher', 'bravo'],
    [6, 'teacher', 'like'], [6, 'salma', 'like'],
    [8, 'student', 'useful'], [8, 'omar', 'useful'],
    [9, 'student', 'like'], [9, 'teacher', 'like'],
    [10, 'teacher', 'bravo'], [10, 'amel', 'bravo'], [10, 'omar', 'bravo'], [10, 'salma', 'like'],
    [11, 'student', 'useful'], [11, 'omar', 'useful'],
    [12, 'salma', 'like'], [12, 'nour', 'useful'],
    [13, 'student', 'useful'], [13, 'omar', 'like'],
    [14, 'student', 'useful'], [14, 'lucas', 'useful'], [14, 'salma', 'like'],
  ];
  for (const [i, who, type] of REACTIONS) {
    await db.doc(`articles/${aid[i]}/reactions/${ids[who]}`).set({ type, createdAt: daysAgo(1) });
    await pause(40);
  }

  // ---------- Annonces partenaires ----------
  const ANNOUNCEMENTS = [
    ['sorbonne', 'partner', 'opportunity', 'Bourses de mobilité Erasmus+ 2027', 'Dix bourses pour un semestre d\'échange en licence 3 ou master 1. Dossier : relevés de notes, lettre de motivation, niveau B2 en français.', 45, 'https://example.org/erasmus', 5],
    ['sorbonne', 'partner', 'event', 'Journée portes ouvertes en ligne', 'Présentation des masters en informatique et en mathématiques appliquées, suivie d\'une séance de questions.', 10, '', 4],
    ['laval', 'partner2', 'opportunity', 'Stages de recherche d\'été au Québec', 'Six stages rémunérés de douze semaines en génie logiciel, intelligence artificielle et énergie. Candidature avant fin février.', 60, 'https://example.org/laval-stages', 8],
    ['laval', 'partner2', 'announcement', 'Nouvelle convention de cotutelle de thèse', 'La convention avec les universités tunisiennes est signée : les doctorants peuvent désormais préparer une cotutelle franco-québécoise.', null, '', 15],
    ['tum', 'admin', 'event', 'Webinaire : étudier en Bavière', 'Présentation des programmes en ingénierie, des conditions d\'admission, du logement et des bourses DAAD.', 21, 'https://example.org/tum-webinaire', 3],
    ['polimi', 'admin', 'opportunity', 'Échanges Erasmus+ en architecture et design', 'Places ouvertes au semestre de printemps. Portfolio et lettre de motivation exigés.', 90, '', 12],
    ['rabat', 'admin', 'announcement', 'Accord de coopération maghrébin', 'Un nouvel accord facilite l\'accueil croisé d\'étudiants en master entre Rabat et les universités tunisiennes.', null, '', 20],
    ['sorbonne', 'partner', 'event', 'Conférence : l\'IA et l\'enseignement supérieur', 'Table ronde avec des enseignants-chercheurs de Paris et de Tunis. Retransmission en direct.', 30, '', 1],
  ];
  for (const [p, who, type, title, description, inDays, link, days] of ANNOUNCEMENTS) {
    await db.collection('announcements').add({
      partnerId: pid[p],
      partnerName: PARTNERS.find((x) => x.key === p).name,
      type, title, description,
      eventDate: inDays == null ? null : daysAgo(-inDays),
      link,
      authorId: ids[who],
      createdAt: daysAgo(days),
    });
    await pause(60);
  }

  // ---------- Conversations : [a, b, [expéditeur, texte, jours], ..., lu par a ?] ----------
  const CONVERSATIONS = [
    ['student', 'teacher', true, [
      ['student', 'Bonjour Monsieur, pourrais-je vous montrer mon plan de PFE ?', 0.3],
      ['teacher', 'Bien sûr, passez à mon bureau jeudi à 14 h.', 0.2],
      ['student', 'Merci beaucoup, je prépare un résumé de deux pages.', 0.15],
      ['teacher', 'Parfait. Apportez aussi les résultats préliminaires de CamemBERT.', 0.05],
    ]],
    ['student', 'omar', true, [
      ['omar', 'Salut Yasmine, tu as le polycopié du chapitre 3 de probabilités ?', 4],
      ['student', 'Oui, je te l\'envoie ce soir.', 3.9],
      ['omar', 'Super, merci ! On révise ensemble samedi ?', 3.8],
      ['student', 'Avec plaisir, à la bibliothèque à 10 h.', 3.7],
    ]],
    ['student', 'salma', false, [
      ['salma', 'Ton article sur le hackathon m\'a donné envie de participer !', 1.2],
      ['student', 'Il y en a un le mois prochain, je te passe le lien.', 1.1],
      ['salma', 'Génial. Tu cherches encore un développeur front-end ?', 0.4],
    ]],
    ['student', 'lucas', false, [
      ['lucas', 'Bonjour ! Je suis étudiant Erasmus à Tunis. Pourrais-tu me conseiller un logement ?', 0.6],
    ]],
    ['teacher', 'amel', true, [
      ['teacher', 'Amel, souhaites-tu co-encadrer un projet de master sur les graphes ?', 6],
      ['amel', 'Avec plaisir. Envoie-moi le sujet et je regarde.', 5.5],
    ]],
    ['pierre', 'student', false, [
      ['pierre', 'Bonjour Yasmine, votre dossier de double diplôme est bien reçu. Il manque une lettre de recommandation.', 0.9],
    ]],
    ['admin', 'partner', true, [
      ['admin', 'Bonjour, votre annonce Erasmus+ est publiée. Merci pour votre contribution.', 5],
      ['partner', 'Merci ! Nous publierons un rappel avant la date limite.', 4.9],
    ]],
  ];
  for (const [a, b, readByFirst, messages] of CONVERSATIONS) {
    const convId = [ids[a], ids[b]].sort().join('_');
    const last = messages[messages.length - 1];
    const conv = db.doc(`conversations/${convId}`);
    await conv.set({
      participants: [ids[a], ids[b]].sort(),
      names: { [ids[a]]: byKey[a].displayName, [ids[b]]: byKey[b].displayName },
      lastMessage: last[1],
      lastSenderId: ids[last[0]],
      lastMessageAt: daysAgo(last[2]),
      // Lue par l'expéditeur du dernier message ; lue aussi par l'autre si readByFirst.
      readBy: readByFirst ? [ids[a], ids[b]] : [ids[last[0]]],
    });
    for (const [sender, text, days] of messages) {
      await conv.collection('messages').add({ senderId: ids[sender], text, createdAt: daysAgo(days) });
    }
  }

  await pause(2000); // laisse les Functions terminer (compteurs, notifications)

  console.log(`Données de démonstration créées : ${USERS.length} comptes, ${PARTNERS.length} universités, ${ARTICLES.length} publications, ${COMMENTS.length} commentaires, ${ANNOUNCEMENTS.length} annonces, ${CONVERSATIONS.length} conversations.`);
  console.log('Comptes (mot de passe « edushare123 ») :');
  for (const u of USERS) console.log(`  ${u.role.padEnd(8)} ${u.email.padEnd(28)} ${u.displayName}`);
}

main().then(() => process.exit(0), (e) => { console.error(e); process.exit(1); });
