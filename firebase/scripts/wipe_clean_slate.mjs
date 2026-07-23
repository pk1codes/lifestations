#!/usr/bin/env node
/**
 * CLEAN SLATE wipe for project aaaa-4eee0.
 *
 * Deletes: Firestore user/content collections, Storage media prefixes,
 * and all Auth users. Keeps rules / indexes / functions (not touched).
 *
 * Requires Admin SDK JSON for THIS project (not another Firebase project):
 *   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/aaaa-adminsdk.json
 *   cd firebase/scripts && node wipe_clean_slate.mjs --confirm
 *
 * Without --confirm the script only prints what it would wipe.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import admin from 'firebase-admin';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const confirm = process.argv.includes('--confirm');

// Prefer live project id from .firebaserc (web_config may still be placeholders).
function resolveProject() {
  try {
    const rc = JSON.parse(
      fs.readFileSync(path.resolve(__dirname, '../.firebaserc'), 'utf8'),
    );
    if (rc.projects?.default) return rc.projects.default;
  } catch (_) {}
  return 'aaaa-4eee0';
}

const projectId = resolveProject();
const storageBucket = `${projectId}.firebasestorage.app`;

function initAdmin() {
  if (admin.apps.length > 0) return;
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credPath || !fs.existsSync(credPath)) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS to the aaaa-4eee0 Admin SDK JSON.\n' +
        'Firebase Console → Project settings → Service accounts → Generate new private key.\n' +
        '(Do not use marriage-71efc or any other project key.)',
    );
  }
  const json = JSON.parse(fs.readFileSync(credPath, 'utf8'));
  if (json.project_id && json.project_id !== projectId) {
    throw new Error(
      `Credential project ${json.project_id} != expected ${projectId}. Refusing wipe.`,
    );
  }
  admin.initializeApp({
    credential: admin.credential.cert(json),
    projectId,
    storageBucket,
  });
}

async function deleteCollection(db, path, batchSize = 400) {
  const col = db.collection(path);
  let total = 0;
  for (;;) {
    const snap = await col.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const doc of snap.docs) batch.delete(doc.ref);
    await batch.commit();
    total += snap.size;
  }
  return total;
}

async function deleteDocRecursive(db, ref) {
  const cols = await ref.listCollections();
  for (const col of cols) {
    const snap = await col.get();
    for (const doc of snap.docs) {
      await deleteDocRecursive(db, doc.ref);
      await doc.ref.delete();
    }
  }
}

async function wipeUsersTree(db) {
  const users = await db.collection('users').get();
  let n = 0;
  for (const doc of users.docs) {
    await deleteDocRecursive(db, doc.ref);
    await doc.ref.delete();
    n += 1;
  }
  return n;
}

async function wipeDomains(db) {
  const domains = [
    'marriage',
    'jobs',
    'kuwait_jobs',
    'rooms',
    'bikes',
    'home_help',
  ];
  const subcols = [
    'profiles',
    'offers',
    'public_cards',
    'likes',
  ];
  let total = 0;
  for (const domain of domains) {
    for (const sub of subcols) {
      // likes has nested paths — delete recursively via domain doc children
      const col = db.collection(`domains/${domain}/${sub}`);
      const snap = await col.get();
      for (const doc of snap.docs) {
        await deleteDocRecursive(db, doc.ref);
        await doc.ref.delete();
        total += 1;
      }
    }
    // domain root meta if any
    const root = await db.doc(`domains/${domain}`).get();
    if (root.exists) {
      await deleteDocRecursive(db, root.ref);
      await root.ref.delete();
      total += 1;
    }
  }
  return total;
}

async function wipeTopLevel(db) {
  const tops = [
    'otp_trackers',
    'reports',
    'image_flags',
    'action_throttles',
    'feed_throttles',
    'share_slugs',
  ];
  let total = 0;
  for (const name of tops) {
    total += await deleteCollection(db, name);
  }
  return total;
}

async function wipeStorage(bucket) {
  const prefixes = [
    'media/',
    'profile_photos/',
    'verify_staging/',
    'listing_photos/',
    'identity/',
  ];
  let files = 0;
  for (const prefix of prefixes) {
    const [list] = await bucket.getFiles({ prefix });
    if (list.length === 0) continue;
    await bucket.deleteFiles({ prefix, force: true });
    files += list.length;
  }
  return files;
}

async function wipeAuth() {
  const auth = admin.auth();
  let deleted = 0;
  let nextPageToken;
  do {
    const result = await auth.listUsers(1000, nextPageToken);
    for (const user of result.users) {
      await auth.deleteUser(user.uid);
      deleted += 1;
    }
    nextPageToken = result.pageToken;
  } while (nextPageToken);
  return deleted;
}

async function main() {
  console.log(`Clean-slate wipe target project: ${projectId}`);
  console.log(`Storage bucket: ${storageBucket}`);
  if (!confirm) {
    console.log('Dry run only. Re-run with --confirm to execute.');
    process.exit(0);
  }
  initAdmin();
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  console.log('Wiping users/…');
  console.log('  users docs:', await wipeUsersTree(db));
  console.log('Wiping domains/…');
  console.log('  domain docs:', await wipeDomains(db));
  console.log('Wiping top-level collections…');
  console.log('  top-level docs:', await wipeTopLevel(db));
  console.log('Wiping Storage prefixes…');
  console.log('  storage files (listed):', await wipeStorage(bucket));
  console.log('Wiping Auth users…');
  console.log('  auth users:', await wipeAuth());
  console.log('Clean slate complete. Rules/indexes/functions untouched.');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
