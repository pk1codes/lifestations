#!/usr/bin/env node
/**
 * Legacy bike-offer cleanup (Admin SDK).
 *
 * For each domains/bikes/offers/{id}:
 *   attributes.rcUrl        → attributes.hasRc = true, delete rcUrl
 *   attributes.insuranceUrl → attributes.hasInsurance = true, delete insuranceUrl
 *
 * Leaves private Storage objects untouched.
 * Logs only offer IDs — never URLs.
 *
 *   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/adminsdk.json
 *   cd firebase/scripts && npm run cleanup:bike-docs
 *
 * Rotate any Admin SDK key that was ever committed or shared.
 */
import fs from 'fs';
import admin from 'firebase-admin';
import { projectId } from './lib/firebase_config.mjs';

function initAdmin() {
  if (admin.apps.length) return;
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credPath || !fs.existsSync(credPath)) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS to an Admin SDK JSON outside the repo.',
    );
  }
  if (projectId.startsWith('YOUR_')) {
    throw new Error('Fill firebase/web_config.json projectId before cleanup.');
  }
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(fs.readFileSync(credPath))),
    projectId,
  });
}

async function main() {
  initAdmin();
  const db = admin.firestore();
  const snap = await db
    .collection('domains')
    .doc('bikes')
    .collection('offers')
    .get();

  let scanned = 0;
  let updated = 0;

  for (const doc of snap.docs) {
    scanned += 1;
    const data = doc.data() || {};
    const attrs = { ...(data.attributes || {}) };
    const hadRc = Object.prototype.hasOwnProperty.call(attrs, 'rcUrl');
    const hadIns = Object.prototype.hasOwnProperty.call(attrs, 'insuranceUrl');
    if (!hadRc && !hadIns) continue;

    if (hadRc) {
      attrs.hasRc = true;
      delete attrs.rcUrl;
    }
    if (hadIns) {
      attrs.hasInsurance = true;
      delete attrs.insuranceUrl;
    }

    await doc.ref.update({ attributes: attrs });
    updated += 1;
    console.log('stripped', doc.id);
  }

  console.log(JSON.stringify({ scanned, updated }, null, 2));
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
