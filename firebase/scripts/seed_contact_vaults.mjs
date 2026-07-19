#!/usr/bin/env node
/**
 * Writes ContactVault docs for seed profile IDs.
 * Demo contacts stay private — never written to discovery profiles.
 *
 *   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/adminsdk.json
 *   cd firebase/scripts && npm run seed:vaults
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import admin from 'firebase-admin';
import { projectId } from './lib/firebase_config.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../..');

function initAdmin() {
  if (admin.apps.length) return;
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credPath || !fs.existsSync(credPath)) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS to an Admin SDK JSON outside the repo.',
    );
  }
  if (projectId.startsWith('YOUR_')) {
    throw new Error('Fill firebase/web_config.json projectId before seeding vaults.');
  }
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(fs.readFileSync(credPath))),
    projectId,
  });
}

async function upsertVault(db, uid, whatsapp, telegram, displayName) {
  const digits = String(whatsapp || '').replace(/\D/g, '');
  if (digits.length < 8) return false;
  await db.collection('users').doc(uid).collection('private').doc('contact').set(
    {
      whatsappNumber: digits.slice(0, 15),
      telegramHandle: String(telegram || '').replace(/^@/, '').slice(0, 40),
      displayName: String(displayName || '').slice(0, 60),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      seeded: true,
    },
    { merge: true },
  );
  return true;
}

function telegramFrom(name, existing) {
  if (existing && String(existing).trim()) {
    return String(existing).replace(/^@/, '');
  }
  return String(name || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '')
    .trim();
}

async function seedFromJson(db) {
  let n = 0;
  for (const rel of [
    'initial_seeds/profiles.json',
    'initial_seeds/jobs/profiles.json',
  ]) {
    const abs = path.join(root, rel);
    if (!fs.existsSync(abs)) continue;
    const profiles = JSON.parse(fs.readFileSync(abs, 'utf8')).profiles ?? [];
    for (const p of profiles) {
      const ok = await upsertVault(
        db,
        p.id,
        p.whatsappNumber,
        telegramFrom(p.name, p.telegramHandle),
        p.name,
      );
      if (ok) n += 1;
    }
  }
  return n;
}

async function main() {
  initAdmin();
  const db = admin.firestore();
  console.log('Seeding contact vaults only…');
  const count = await seedFromJson(db);
  console.log(`  vaults upserted: ${count}`);
  console.log('Done.');
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
