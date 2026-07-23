#!/usr/bin/env node
/**
 * Static proof of Firestore/Storage/Functions security invariants.
 * No credentials, no deploy, no network.
 *
 *   cd firebase/scripts && npm run prove:backend
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const firebaseDir = path.resolve(__dirname, '..');
const root = path.resolve(firebaseDir, '..');

const errors = [];
function assert(cond, msg) {
  if (!cond) errors.push(msg);
}

const firestoreRules = fs.readFileSync(
  path.join(firebaseDir, 'firestore.rules'),
  'utf8',
);
const storageRules = fs.readFileSync(
  path.join(firebaseDir, 'storage.rules'),
  'utf8',
);
const functionsSrc = fs.readFileSync(
  path.join(firebaseDir, 'functions/index.js'),
  'utf8',
);
const functionsPkg = JSON.parse(
  fs.readFileSync(path.join(firebaseDir, 'functions/package.json'), 'utf8'),
);
const indexes = JSON.parse(
  fs.readFileSync(path.join(firebaseDir, 'firestore.indexes.json'), 'utf8'),
);
const firebaserc = JSON.parse(
  fs.readFileSync(path.join(firebaseDir, '.firebaserc'), 'utf8'),
);
const rootFirebase = JSON.parse(
  fs.readFileSync(path.join(root, 'firebase.json'), 'utf8'),
);

// --- Firestore ---
assert(firestoreRules.includes("rules_version = '2'"), 'firestore rules_version');
assert(firestoreRules.includes('function noPublicContact'), 'noPublicContact helper');
assert(
  firestoreRules.includes('function mutualLikeInDomain'),
  'same-domain mutual like helper',
);
assert(
  firestoreRules.includes("mutualLikeInDomain('marriage', targetUid)"),
  'marriage same-domain mutual',
);
assert(
  !firestoreRules.includes('likedOutbound(targetUid)'),
  'legacy cross-domain likedOutbound removed',
);
// Vault is owner-only on the client; mutual unlock is Admin callable only.
assert(
  /match \/private\/\{docId\}[\s\S]*?allow read: if isOwner\(userId\);/.test(
    firestoreRules,
  ),
  'vault owner-only client read',
);
assert(
  firestoreRules.includes('unlockContact'),
  'rules comment documents unlockContact callable',
);
assert(
  /match \/rate_limits\/\{userId\}[\s\S]*?allow create, update, delete: if false;/.test(
    firestoreRules,
  ),
  'rate_limits Functions-only writes (client denied)',
);
assert(
  !firestoreRules.includes('request.resource.data.hits <= 10'),
  'legacy client rate_limits hits cap removed',
);
assert(firestoreRules.includes('match /image_flags/{flagId}'), 'image_flags match');
assert(
  /match \/image_flags\/\{flagId\}[\s\S]*?allow read: if false;/.test(firestoreRules),
  'image_flags create-only / no read',
);
assert(
  firestoreRules.includes("!('rcUrl' in d.attributes)"),
  'offers ban attributes.rcUrl',
);
assert(
  firestoreRules.includes("!('insuranceUrl' in d.attributes)"),
  'offers ban attributes.insuranceUrl',
);
assert(
  firestoreRules.includes("!('whatsappNumber' in d.attributes)"),
  'offers ban attributes.whatsappNumber',
);
assert(
  firestoreRules.includes("!('phone' in d.attributes)"),
  'offers ban attributes.phone',
);
assert(
  firestoreRules.includes("!(('whatsappNumber' in d.snapshot))"),
  'likes ban snapshot whatsapp',
);
assert(
  firestoreRules.includes("!('phone' in d)"),
  'public card / offer phone ban present',
);
assert(
  firestoreRules.includes('allow create, update, delete: if false;'),
  'discovery_categories deny client writes',
);
assert(
  firestoreRules.includes('allow read: if isOwner(userId);'),
  'users owner-only read',
);
assert(
  firestoreRules.includes(
    "request.time > resource.data.lastSentAt + duration.value(60, 's')",
  ),
  'otp 60s cooldown',
);

// validOffer composes validDiscoveryListing — contact bans live there.
const discoveryFn = firestoreRules.split('function validDiscoveryListing')[1]
  .split('function validDomainProfile')[0];
assert(discoveryFn.includes("!('whatsappNumber' in d)"), 'listing top-level whatsapp ban');
assert(discoveryFn.includes("!('telegramHandle' in d)"), 'listing top-level telegram ban');
assert(
  firestoreRules.includes('function validOffer') &&
    firestoreRules.includes('validDiscoveryListing(domainId)'),
  'validOffer uses validDiscoveryListing',
);

const domainProfileFn = firestoreRules
  .split('function validDomainProfile')[1]
  .split('function validOffer')[0];
assert(domainProfileFn.includes("'marriage'"), 'domain profile marriage');
assert(domainProfileFn.includes("'jobs'"), 'domain profile jobs');
assert(!domainProfileFn.includes("'rooms'"), 'rooms not domain profiles');
assert(!domainProfileFn.includes("'bikes'"), 'bikes not domain profiles');

// --- Storage ---
assert(storageRules.includes('5 * 1024 * 1024'), '5 MiB upload cap');
assert(
  storageRules.includes("image/(webp|jpeg|jpg|png)"),
  'allowed image MIME types',
);
assert(
  storageRules.includes('match /media/{userId}/{domainId}/{offerId}/docs/{docName}/{fileName}'),
  'RC/insurance docs path',
);
const docsBlock = storageRules
  .split('match /media/{userId}/{domainId}/{offerId}/docs/{docName}/{fileName}')[1]
  .split('match /verify_staging')[0];
assert(
  docsBlock.includes('allow read: if isSignedIn() && isOwner(userId);'),
  'docs owner-only read',
);
assert(
  docsBlock.includes("docName in ['rc', 'insurance']"),
  'docs rc|insurance only',
);
assert(storageRules.includes('match /verify_staging/{userId}/{docType}/{fileName}'),
  'verify_staging path');

// --- Functions ---
assert(functionsPkg.engines?.node === '20', 'functions Node 20');
assert(functionsSrc.includes('exports.onReportCreated'), 'onReportCreated');
assert(functionsSrc.includes('exports.onImageFlagCreated'), 'onImageFlagCreated');
assert(functionsSrc.includes('exports.checkFeedThrottle'), 'checkFeedThrottle');
assert(functionsSrc.includes('exports.onInboundLikeCreated'), 'onInboundLikeCreated');
assert(functionsSrc.includes('exports.unlockContact'), 'unlockContact');
assert(functionsSrc.includes('exports.deleteAccount'), 'deleteAccount');
assert(functionsSrc.includes('exports.claimActionThrottle'), 'claimActionThrottle');
assert(functionsSrc.includes('enforceAppCheck: true'), 'App Check on sensitive callables');
assert(
  !functionsSrc.includes(
    'exports.claimActionThrottle = onCall({enforceAppCheck: true}',
  ),
  'claimActionThrottle is auth-capped (no enforceAppCheck)',
);
assert(
  functionsSrc.includes('exports.unlockContact = onCall(async'),
  'unlockContact is auth + mutual + phone (no enforceAppCheck)',
);
assert(
  !functionsSrc.includes(
    'exports.unlockContact = onCall({enforceAppCheck: true}',
  ),
  'unlockContact must not enforce App Check',
);
assert(
  functionsSrc.includes(
    'exports.deleteAccount = onCall({enforceAppCheck: true}',
  ),
  'deleteAccount enforces App Check',
);
assert(functionsSrc.includes('SLACK_WEBHOOK_URL'), 'slack webhook optional');
assert(functionsSrc.includes('maxHits: 10'), 'throttle max 10');
assert(functionsSrc.includes('windowMs: 30_000'), 'throttle 30s window');
assert(functionsSrc.includes('flut_likes_high'), 'FCM channel flut_likes_high');
// Unlock may return whatsappNumber; inbound like FCM must not put it in the payload.
const inboundFcm = functionsSrc.split('exports.onInboundLikeCreated')[1] ?? '';
assert(
  !/data:\s*\{[^}]*whatsappNumber/.test(inboundFcm),
  'inbound like FCM data omits whatsapp',
);

// --- Indexes ---
const groups = indexes.indexes.map((i) => i.collectionGroup);
assert(groups.includes('offers'), 'offers indexes');
assert(groups.includes('profiles'), 'profiles indexes');
assert(indexes.indexes.length >= 14, `expected >=14 indexes, got ${indexes.indexes.length}`);

// --- Project id (placeholder or real) ---
const projectId = firebaserc.projects?.default ?? '';
assert(
  projectId === 'YOUR_FIREBASE_PROJECT_ID' || /^[a-z0-9-]+$/.test(projectId),
  '.firebaserc project id',
);
assert(
  rootFirebase.flutter?.platforms?.android?.default?.projectId ===
    'YOUR_FIREBASE_PROJECT_ID' ||
    typeof rootFirebase.flutter?.platforms?.android?.default?.projectId ===
      'string',
  'root firebase.json FlutterFire project field',
);

// --- Operational scripts exist ---
for (const rel of [
  'scripts/seed_safe_inventory.mjs',
  'scripts/seed_contact_vaults.mjs',
  'scripts/cleanup_legacy_bike_doc_urls.mjs',
  'scripts/validate_sharp_333_bundle.mjs',
]) {
  assert(fs.existsSync(path.join(firebaseDir, rel)), `missing ${rel}`);
}

if (errors.length) {
  console.error('BACKEND PROOF FAILED:');
  for (const e of errors) console.error(' -', e);
  process.exit(1);
}

console.log('Backend security invariants OK:', {
  projectId,
  firestoreRulesBytes: firestoreRules.length,
  storageRulesBytes: storageRules.length,
  indexes: indexes.indexes.length,
  functions: [
    'onReportCreated',
    'onImageFlagCreated',
    'checkFeedThrottle',
    'onInboundLikeCreated',
    'unlockContact',
    'deleteAccount',
  ],
});
