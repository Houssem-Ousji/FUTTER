/**
 * Cloud Functions EduShare.
 *
 * - Compteurs : commentaires et réactions par publication, statistiques
 *   d'activité par utilisateur (users/{uid}.stats).
 * - Notifications in-app (users/{uid}/notifications) + push FCM.
 * - Nettoyage : sous-collections d'une publication supprimée, annonces
 *   d'une université retirée.
 *
 * Chaque push porte data.route : l'écran que l'application ouvre au toucher.
 */
const { setGlobalOptions } = require('firebase-functions/v2');
const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

const db = getFirestore();
const ANNOUNCEMENTS_TOPIC = 'announcements';
// FCM n'a pas d'émulateur : en local, les push sont seulement journalisés.
const IS_EMULATOR = process.env.FUNCTIONS_EMULATOR === 'true';
const NOT_FOUND = 5;
const INVALID_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

function truncate(text, max = 120) {
  if (!text) return '';
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/** Met à jour un document s'il existe encore (ignore NOT_FOUND). */
async function updateIfExists(ref, data) {
  try {
    await ref.update(data);
  } catch (error) {
    if (error.code !== NOT_FOUND) throw error;
  }
}

function incrementUserStat(uid, field, delta) {
  if (!uid || delta === 0) return Promise.resolve();
  return updateIfExists(db.doc(`users/${uid}`), {
    [`stats.${field}`]: FieldValue.increment(delta),
  });
}

/** Envoie un push à tous les appareils de l'utilisateur et purge les jetons invalides. */
async function sendPush(uid, { title, body, route }) {
  if (IS_EMULATOR) {
    console.log(`[push émulé] ${uid} — ${title} : ${body} (${route})`);
    return;
  }
  const tokensSnap = await db.collection(`users/${uid}/tokens`).get();
  if (tokensSnap.empty) return;
  const tokens = tokensSnap.docs.map((doc) => doc.id);
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { route: route || '' },
    android: { priority: 'high' },
  });
  const cleanup = [];
  response.responses.forEach((result, i) => {
    if (!result.success && INVALID_TOKEN_CODES.includes(result.error?.code)) {
      cleanup.push(tokensSnap.docs[i].ref.delete());
    }
  });
  await Promise.all(cleanup);
}

/** Notification in-app + push. */
async function notify(uid, { type, title, body, route }) {
  await db.collection(`users/${uid}/notifications`).add({
    type,
    title,
    body,
    route,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  await sendPush(uid, { title, body, route });
}

async function displayName(uid) {
  const snap = await db.doc(`users/${uid}`).get();
  return snap.get('displayName') || "Quelqu'un";
}

// ---------- Publications ----------

exports.onArticleCreated = onDocumentCreated('articles/{articleId}', (event) =>
  incrementUserStat(event.data.data().authorId, 'articles', 1),
);

exports.onArticleDeleted = onDocumentDeleted('articles/{articleId}', async (event) => {
  const article = event.data.data();
  const reactions = Object.values(article.reactions || {}).reduce((sum, n) => sum + n, 0);
  await incrementUserStat(article.authorId, 'articles', -1);
  await incrementUserStat(article.authorId, 'reactionsReceived', -reactions);
  // Supprime commentaires et réactions. Les fonctions déclenchées par ces
  // suppressions ignorent la publication, qui n'existe plus.
  await db.recursiveDelete(event.data.ref);
});

// ---------- Commentaires ----------

exports.onCommentCreated = onDocumentCreated(
  'articles/{articleId}/comments/{commentId}',
  async (event) => {
    const comment = event.data.data();
    const { articleId } = event.params;
    const articleRef = db.doc(`articles/${articleId}`);

    await updateIfExists(articleRef, { commentCount: FieldValue.increment(1) });
    await incrementUserStat(comment.authorId, 'comments', 1);

    const article = (await articleRef.get()).data();
    if (article && article.authorId !== comment.authorId) {
      await notify(article.authorId, {
        type: 'comment',
        title: `${comment.authorName} a commenté « ${truncate(article.title, 60)} »`,
        body: truncate(comment.text),
        route: `/article/${articleId}`,
      });
    }
  },
);

exports.onCommentDeleted = onDocumentDeleted(
  'articles/{articleId}/comments/{commentId}',
  async (event) => {
    const comment = event.data.data();
    await updateIfExists(db.doc(`articles/${event.params.articleId}`), {
      commentCount: FieldValue.increment(-1),
    });
    await incrementUserStat(comment.authorId, 'comments', -1);
  },
);

// ---------- Réactions ----------

exports.onReactionWritten = onDocumentWritten(
  'articles/{articleId}/reactions/{userId}',
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (before?.type === after?.type) return;

    const { articleId, userId } = event.params;
    const articleRef = db.doc(`articles/${articleId}`);
    const article = (await articleRef.get()).data();
    if (!article) return; // publication supprimée : compteurs déjà soldés

    const update = {};
    if (before) update[`reactions.${before.type}`] = FieldValue.increment(-1);
    if (after) update[`reactions.${after.type}`] = FieldValue.increment(1);
    await updateIfExists(articleRef, update);
    await incrementUserStat(article.authorId, 'reactionsReceived', (after ? 1 : 0) - (before ? 1 : 0));

    if (!before && after && userId !== article.authorId) {
      await notify(article.authorId, {
        type: 'reaction',
        title: 'Nouvelle réaction',
        body: `${await displayName(userId)} a réagi à « ${truncate(article.title, 80)} »`,
        route: `/article/${articleId}`,
      });
    }
  },
);

// ---------- Messagerie ----------

exports.onMessageCreated = onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    const message = event.data.data();
    const { conversationId } = event.params;
    const conversation = (await db.doc(`conversations/${conversationId}`).get()).data();
    if (!conversation) return;
    const senderName = conversation.names?.[message.senderId] || 'Nouveau message';
    const recipients = (conversation.participants || []).filter((p) => p !== message.senderId);
    // Pas de notification in-app pour les messages : le badge de l'onglet suffit.
    await Promise.all(
      recipients.map((uid) =>
        sendPush(uid, {
          title: senderName,
          body: truncate(message.text),
          route: `/chat/${conversationId}`,
        }),
      ),
    );
  },
);

// ---------- Partenaires ----------

exports.onAnnouncementCreated = onDocumentCreated('announcements/{announcementId}', async (event) => {
  const announcement = event.data.data();
  if (IS_EMULATOR) {
    console.log(`[push émulé] sujet ${ANNOUNCEMENTS_TOPIC} — ${announcement.title}`);
    return;
  }
  await getMessaging().send({
    topic: ANNOUNCEMENTS_TOPIC,
    notification: {
      title: `${announcement.partnerName} : ${truncate(announcement.title, 80)}`,
      body: truncate(announcement.description),
    },
    data: { route: `/partner/${announcement.partnerId}` },
  });
});

exports.onPartnerDeleted = onDocumentDeleted('partners/{partnerId}', async (event) => {
  const { partnerId } = event.params;
  const announcements = await db
    .collection('announcements')
    .where('partnerId', '==', partnerId)
    .get();
  const writer = db.bulkWriter();
  announcements.docs.forEach((doc) => writer.delete(doc.ref));
  // Les représentants de l'université perdent leur rôle partenaire.
  const members = await db.collection('users').where('partnerId', '==', partnerId).get();
  members.docs.forEach((doc) => writer.update(doc.ref, { role: 'student', partnerId: null }));
  await writer.close();
});
