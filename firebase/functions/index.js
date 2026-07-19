/**
 * Lean safety ops — Slack webhook on reports / image_flags + feed throttle + FCM likes.
 *
 * Setup:
 *   cd firebase/functions && npm install
 *   # Optional Slack: export SLACK_WEBHOOK_URL=... before deploy, or set in
 *   # Google Cloud Console → Cloud Functions → Runtime env vars.
 *   firebase deploy --only functions
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const { logger } = require("firebase-functions");

initializeApp();

async function postSlack(text, urgent) {
  const url = process.env.SLACK_WEBHOOK_URL;
  if (!url) {
    logger.warn("SLACK_WEBHOOK_URL unset — skipping notify");
    return;
  }
  const payload = {
    text: urgent ? `:rotating_light: ${text}` : text,
  };
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    logger.error("Slack webhook failed", res.status, await res.text());
  }
}

exports.onReportCreated = onDocumentCreated(
  {
    document: "reports/{id}",
  },
  async (event) => {
    const data = event.data?.data() || {};
    const urgent = data.urgent === true ||
      data.reason === "underage" ||
      data.reason === "child_safety";
    await postSlack(
      `New *user report* (${data.reason || "?"}) · domain=${data.domain || "?"} · target=\`${data.targetId || "?"}\` · reporter=\`${data.reporterUid || "?"}\``,
      urgent,
    );
  },
);

exports.onImageFlagCreated = onDocumentCreated(
  {
    document: "image_flags/{id}",
  },
  async (event) => {
    const data = event.data?.data() || {};
    const urgent =
      data.reason === "underage" || data.reason === "child_safety";
    await postSlack(
      `New *photo flag* (${data.reason || "?"}) · domain=${data.domain || "?"} · target=\`${data.targetId || "?"}\` · reporter=\`${data.reporterUid || "?"}\``,
      urgent,
    );
  },
);

/** Server-side feed throttle — pairs with client FeedFetchThrottle. */
exports.checkFeedThrottle = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.auth.uid;
  const db = getFirestore();
  const ref = db.collection("rate_limits").doc(uid);
  const now = Date.now();
  const windowMs = 30_000;
  const maxHits = 10;

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : {};
    let hits = typeof data.hits === "number" ? data.hits : 0;
    let windowStartMs =
      typeof data.windowStartMs === "number" ? data.windowStartMs : now;
    let lockedUntilMs =
      typeof data.lockedUntilMs === "number" ? data.lockedUntilMs : 0;

    if (lockedUntilMs > now) {
      return { allowed: false, lockedUntilMs };
    }
    if (now - windowStartMs > windowMs) {
      hits = 0;
      windowStartMs = now;
    }
    hits += 1;
    if (hits > maxHits) {
      lockedUntilMs = now + windowMs;
      tx.set(
        ref,
        {
          hits,
          windowStartMs,
          lockedUntilMs,
          updatedAt: now,
        },
        { merge: true },
      );
      return { allowed: false, lockedUntilMs };
    }
    tx.set(
      ref,
      {
        hits,
        windowStartMs,
        lockedUntilMs: 0,
        updatedAt: now,
      },
      { merge: true },
    );
    return { allowed: true, lockedUntilMs: 0 };
  });

  return result;
});

/**
 * Server-validated contact unlock.
 * Requires non-anonymous auth with phone, plus same-domain mutual likes.
 * Returns only whatsapp/telegram — never logs them.
 */
exports.unlockContact = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (request.auth.token?.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("permission-denied", "Phone verification required.");
  }
  if (!request.auth.token?.phone_number) {
    throw new HttpsError("permission-denied", "Phone verification required.");
  }
  const domainId = String(request.data?.domainId || "");
  const targetUid = String(request.data?.targetUid || "");
  const allowed = ["marriage", "jobs", "rooms", "bikes", "home_help"];
  if (!allowed.includes(domainId) || targetUid.length < 2) {
    throw new HttpsError("invalid-argument", "Invalid domain or target.");
  }
  const uid = request.auth.uid;
  if (uid === targetUid) {
    throw new HttpsError("invalid-argument", "Cannot unlock own contact.");
  }
  const db = getFirestore();
  const outbound = await db
    .doc(`domains/${domainId}/likes/${uid}/outbound/${targetUid}`)
    .get();
  const inbound = await db
    .doc(`domains/${domainId}/likes/${uid}/inbound/${targetUid}`)
    .get();
  if (!outbound.exists || !inbound.exists) {
    throw new HttpsError("permission-denied", "Mutual interest required.");
  }
  const vault = await db.doc(`users/${targetUid}/private/contact`).get();
  if (!vault.exists) {
    return { found: false };
  }
  const data = vault.data() || {};
  const whatsappNumber = String(data.whatsappNumber || "").replace(/\D/g, "");
  if (whatsappNumber.length < 8) {
    return { found: false };
  }
  return {
    found: true,
    whatsappNumber,
    telegramHandle: data.telegramHandle || null,
  };
});

/** High-priority FCM when someone likes you (inbound like doc created). */

/**
 * Hosting CDN front for public user media.
 * Hosting rewrites `/i/**` → this function. First miss streams from Storage
 * with Cache-Control: public,max-age=31536000,immutable so subsequent hits
 * are served from the Hosting edge without invoking the function again.
 */
exports.serveMedia = onRequest(
  {
    region: "us-central1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== "GET" && req.method !== "HEAD") {
      res.status(405).send("Method not allowed");
      return;
    }

    let objectPath = (req.path || "")
      .replace(/^\/+/, "")
      .replace(/^i\//, "");
    try {
      objectPath = decodeURIComponent(objectPath);
    } catch (_) {
      res.status(400).send("Bad path");
      return;
    }

    if (
      !/^(profile_photos|media)\//.test(objectPath) ||
      !/\.(webp|jpe?g|png)$/i.test(objectPath) ||
      objectPath.includes("..")
    ) {
      res.status(403).send("Forbidden");
      return;
    }

    try {
      const file = getStorage().bucket().file(objectPath);
      const [exists] = await file.exists();
      if (!exists) {
        res.status(404).send("Not found");
        return;
      }
      const [metadata] = await file.getMetadata();
      res.set({
        "Cache-Control": "public,max-age=31536000,immutable",
        "Content-Type": metadata.contentType || "image/webp",
      });
      if (metadata.size) {
        res.set("Content-Length", String(metadata.size));
      }
      if (req.method === "HEAD") {
        res.status(200).end();
        return;
      }
      file
        .createReadStream()
        .on("error", (err) => {
          logger.error("serveMedia stream error", err);
          if (!res.headersSent) res.status(500).end();
        })
        .pipe(res);
    } catch (err) {
      logger.error("serveMedia failed", err);
      if (!res.headersSent) res.status(500).send("Error");
    }
  },
);

const DOMAIN_SLUGS = ["marriage", "jobs", "rooms", "bikes", "home_help"];

/**
 * Google Play data-deletion requirement: removes the caller's account and
 * all associated data (private vault, domain listings, photos, likes,
 * blocks, share cards, push tokens, rate limits), then deletes the Auth
 * user. Reports are retained (anonymized reporter) for moderation duty.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const db = getFirestore();

  async function deleteDocTree(ref) {
    await db.recursiveDelete(ref);
  }

  for (const slug of DOMAIN_SLUGS) {
    // Canonical profile-style listing keyed by uid.
    await deleteDocTree(db.doc(`domains/${slug}/profiles/${uid}`))
      .catch((e) => logger.warn("profile delete", slug, e.message));
    // Offer-style listings owned by uid.
    const offers = await db
      .collection(`domains/${slug}/offers`)
      .where("ownerId", "==", uid)
      .get()
      .catch(() => null);
    for (const doc of offers?.docs || []) {
      await deleteDocTree(doc.ref)
        .catch((e) => logger.warn("offer delete", e.message));
    }
    // Likes trees (outbound + inbound written under the user's uid).
    await deleteDocTree(db.doc(`domains/${slug}/likes/${uid}`))
      .catch((e) => logger.warn("likes delete", slug, e.message));
    // Public share cards owned by uid.
    const cards = await db
      .collection(`domains/${slug}/public_cards`)
      .where("ownerId", "==", uid)
      .get()
      .catch(() => null);
    for (const doc of cards?.docs || []) {
      await doc.ref.delete()
        .catch((e) => logger.warn("card delete", e.message));
    }
  }

  // Legacy top-level marriage mirror.
  await deleteDocTree(db.doc(`profiles/${uid}`)).catch(() => {});
  // Private vault, blocks, push tokens.
  await deleteDocTree(db.doc(`users/${uid}`)).catch(() => {});
  await db.doc(`rate_limits/${uid}`).delete().catch(() => {});

  // Uploaded media.
  const bucket = getStorage().bucket();
  await bucket.deleteFiles({ prefix: `profile_photos/${uid}/` })
    .catch((e) => logger.warn("storage profile_photos", e.message));
  await bucket.deleteFiles({ prefix: `media/${uid}/` })
    .catch((e) => logger.warn("storage media", e.message));
  await bucket.deleteFiles({ prefix: `verify_staging/${uid}/` })
    .catch(() => {});

  await getAuth().deleteUser(uid)
    .catch((e) => logger.error("auth delete failed", e.message));
  logger.info("Account deleted", uid);
  return { ok: true };
});

exports.onInboundLikeCreated = onDocumentCreated(
  {
    document: "domains/{domainId}/likes/{ownerUid}/inbound/{fromUid}",
  },
  async (event) => {
    const ownerUid = event.params.ownerUid;
    const fromUid = event.params.fromUid;
    const domainId = event.params.domainId;
    if (!ownerUid || ownerUid === fromUid) return;

    const db = getFirestore();
    const pushSnap = await db
      .collection("users")
      .doc(ownerUid)
      .collection("private")
      .doc("push")
      .get();
    const token = pushSnap.exists ? pushSnap.data()?.fcmToken : null;
    if (!token) {
      logger.info("No FCM token for", ownerUid);
      return;
    }

    const name =
      event.data?.data()?.snapshot?.name || "Someone";
    try {
      await getMessaging().send({
        token,
        notification: {
          title: "Liked you",
          body: `${name} liked your ${domainId} profile`,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "flut_likes_high",
            priority: "high",
          },
        },
        data: {
          type: "inbound_like",
          domain: String(domainId),
          fromUid: String(fromUid),
        },
      });
    } catch (e) {
      logger.error("FCM send failed", e);
    }
  },
);
