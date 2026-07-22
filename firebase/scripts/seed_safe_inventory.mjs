#!/usr/bin/env node
/**
 * Safe Admin seed for discovery inventory.
 *
 * NEVER writes WhatsApp / Telegram / phone into signed-in-readable discovery
 * profiles or offers. Demo contacts go only into users/{uid}/private/contact.
 *
 * Requires credentials outside the repo:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/adminsdk.json
 *   cd firebase/scripts && npm run seed:safe
 *
 * Does not deploy. Does not invent production contacts for live users.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import admin from 'firebase-admin';
import { projectId, storageBucket } from './lib/firebase_config.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../../');
const seedsDir = path.join(root, 'initial_seeds');

function initAdmin() {
  if (admin.apps.length > 0) return;
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credPath || !fs.existsSync(credPath)) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS to an Admin SDK JSON outside the repo.',
    );
  }
  if (projectId.startsWith('YOUR_')) {
    throw new Error(
      'Replace YOUR_FIREBASE_PROJECT_ID placeholders in firebase/web_config.json first.',
    );
  }
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(fs.readFileSync(credPath))),
    projectId,
    storageBucket,
  });
}

function loadJson(rel) {
  const abs = path.join(root, rel);
  if (!fs.existsSync(abs)) {
    throw new Error(`Missing seed file: ${rel}`);
  }
  return JSON.parse(fs.readFileSync(abs, 'utf8'));
}

function emptyPublicContact() {
  return { whatsappNumber: '', telegramHandle: '' };
}

async function upsertVault(db, uid, source) {
  const digits = String(source.whatsappNumber || '')
    .replace(/\D/g, '')
    .slice(0, 15);
  if (digits.length < 8) return;
  await db
    .collection('users')
    .doc(uid)
    .collection('private')
    .doc('contact')
    .set(
      {
        whatsappNumber: digits,
        telegramHandle: String(source.telegramHandle || '').replace(/^@/, '').slice(0, 40),
        displayName: String(source.name || source.displayName || '').slice(0, 60),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        seeded: true,
      },
      { merge: true },
    );
}

async function seedMarriage(db) {
  const { profiles } = loadJson('initial_seeds/profiles.json');
  const { categories } = loadJson('initial_seeds/categories.json');
  const now = admin.firestore.FieldValue.serverTimestamp();
  let n = 0;

  for (const cat of categories) {
    await db
      .collection('domains')
      .doc('marriage')
      .collection('discovery_categories')
      .doc(cat.id)
      .set(
        {
          categoryName: cat.categoryName,
          profileIds: cat.profileIds ?? [],
          region: cat.region ?? '',
          cityId: cat.cityId ?? '',
          order: cat.order ?? 0,
        },
        { merge: true },
      );
  }

  for (const p of profiles) {
    const uid = p.id;
    const publicDoc = {
      name: p.name,
      age: p.age,
      gender: p.gender,
      seeking: p.seeking,
      bio: p.bio,
      location: p.location,
      ...emptyPublicContact(),
      salary: p.salary ?? '',
      religion: p.religion ?? '',
      nativeLanguage: p.nativeLanguage ?? '',
      ageBand: p.ageBand ?? '',
      photos: p.photos ?? [],
      photoUrl: p.photoUrl ?? '',
      photoThumbUrl: p.photoThumbUrl ?? '',
      photoLargeUrl: p.photoLargeUrl ?? '',
      photoPath: `profile_photos/${uid}`,
      userId: uid,
      domain: 'marriage',
      categories: p.categories ?? [],
      cityId: p.cityId ?? '',
      region: p.region ?? '',
      active: true,
      seeded: true,
      updatedAt: now,
      createdAt: now,
    };
    await db.collection('profiles').doc(uid).set(publicDoc, { merge: true });
    await db
      .collection('domains')
      .doc('marriage')
      .collection('profiles')
      .doc(uid)
      .set(publicDoc, { merge: true });
    await upsertVault(db, uid, p);
    n += 1;
  }
  return n;
}

async function seedJobs(db) {
  const { profiles } = loadJson('initial_seeds/jobs/profiles.json');
  const { categories } = loadJson('initial_seeds/jobs/categories.json');
  const now = admin.firestore.FieldValue.serverTimestamp();
  let n = 0;

  for (const cat of categories) {
    await db
      .collection('domains')
      .doc('jobs')
      .collection('discovery_categories')
      .doc(cat.id)
      .set(
        {
          categoryName: cat.categoryName,
          offerIds: cat.profileIds ?? cat.offerIds ?? [],
          region: cat.region ?? '',
          cityId: cat.cityId ?? '',
          order: cat.order ?? 0,
        },
        { merge: true },
      );
  }

  for (const p of profiles) {
    const uid = p.id;
    const role = p.jobsRole ?? p.role ?? 'seek';
    const trade =
      p.tradeId ||
      (Array.isArray(p.categories) && p.categories[0]) ||
      'Cook';
    const cityLabel = p.cityLabel || p.location || 'Mumbai & MMR';
    const cityId =
      p.cityId ||
      (String(cityLabel).toLowerCase().includes('delhi')
        ? 'delhi'
        : String(cityLabel).toLowerCase().includes('bengal')
          ? 'bengaluru'
          : 'mumbai');
    const salaryBand = p.salaryBand || 'Prefer not to say';
    const photoUrls = p.photoSlots || p.photos || [];
    const attributes = {
      tradeId: trade,
      salaryBand,
    };
    if (role === 'offer') {
      attributes.howMany = p.howMany || '1';
    }
    const publicDoc = {
      id: uid,
      domainId: 'jobs',
      ownerId: uid,
      title: trade,
      subtitle: salaryBand,
      cityId,
      cityLabel,
      categoryTags: [trade],
      photoUrls,
      role,
      attributes,
      verified: p.verifiedUser === true,
      active: true,
      seeded: true,
      updatedAt: now,
      refreshedAt: now,
      createdAt: now,
    };
    await db
      .collection('domains')
      .doc('jobs')
      .collection('offers')
      .doc(uid)
      .set(publicDoc, { merge: true });
    await upsertVault(db, uid, p);
    n += 1;
  }
  return n;
}

function scrubOfferAttributes(attrs = {}) {
  const out = { ...attrs };
  delete out.whatsappNumber;
  delete out.telegramHandle;
  delete out.phone;
  delete out.rcUrl;
  delete out.insuranceUrl;
  if (attrs.rcUrl) out.hasRc = true;
  if (attrs.insuranceUrl) out.hasInsurance = true;
  return out;
}

async function seedOffers(db, domain, fileRel) {
  const payload = loadJson(fileRel);
  const offers = payload.offers ?? [];
  const categories = loadJson(
    fileRel.replace(/offers\.json$/, 'categories.json'),
  ).categories;
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const cat of categories) {
    await db
      .collection('domains')
      .doc(domain)
      .collection('discovery_categories')
      .doc(cat.id)
      .set(
        {
          categoryName: cat.categoryName,
          offerIds: cat.offerIds ?? [],
          region: cat.region ?? '',
          cityId: cat.cityId ?? '',
          order: cat.order ?? 0,
        },
        { merge: true },
      );
  }

  let n = 0;
  for (const o of offers) {
    const ownerId = o.ownerId ?? o.userId ?? o.id;
    const doc = {
      ownerId,
      userId: ownerId,
      domain,
      title: o.title,
      body: o.body ?? o.subtitle ?? '',
      role: o.role ?? '',
      cityId: o.cityId ?? '',
      cityLabel: o.cityLabel ?? o.location ?? '',
      categoryTags: o.categoryTags ?? o.categories ?? [],
      categories: o.categories ?? [],
      photos: o.photos ?? [],
      photoUrl: o.photoUrl ?? '',
      photoThumbUrl: o.photoThumbUrl ?? '',
      photoLargeUrl: o.photoLargeUrl ?? '',
      attributes: scrubOfferAttributes(o.attributes ?? {}),
      active: o.active !== false,
      seeded: true,
      updatedAt: now,
      createdAt: now,
    };
    await db
      .collection('domains')
      .doc(domain)
      .collection('offers')
      .doc(o.id)
      .set(doc, { merge: true });
    n += 1;
  }
  return n;
}

async function main() {
  if (!fs.existsSync(seedsDir)) {
    throw new Error('initial_seeds/ missing — generate the seed bundle first.');
  }
  initAdmin();
  const db = admin.firestore();
  console.log('Safe seed (public contact fields empty)…');
  console.log('  marriage:', await seedMarriage(db));
  console.log('  jobs:', await seedJobs(db));
  console.log('  rooms:', await seedOffers(db, 'rooms', 'initial_seeds/rooms/offers.json'));
  console.log('  bikes:', await seedOffers(db, 'bikes', 'initial_seeds/bikes/offers.json'));
  console.log(
    '  home_help:',
    await seedOffers(db, 'home_help', 'initial_seeds/home_help/offers.json'),
  );
  console.log('Done. Rotate Admin SDK keys if they were ever shared.');
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
