#!/usr/bin/env node
/** Validates the Sharp 3×3×3 seed contract. */
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../../');
const manifest = JSON.parse(
  fs.readFileSync(path.join(root, 'initial_seeds/manifest.json'), 'utf8'),
);

const errors = [];
const assert = (cond, msg) => {
  if (!cond) errors.push(msg);
};

assert(manifest.counts.images === 135, `images=${manifest.counts.images}`);
assert(manifest.counts.uniqueSha256 === 135, 'duplicate hashes in manifest');
assert(manifest.domains.length === 5, 'need 5 domains');

const hashes = new Set();
for (const img of manifest.images) {
  const abs = path.join(root, img.path);
  assert(fs.existsSync(abs), `missing ${img.path}`);
  const buf = fs.readFileSync(abs);
  const sha = crypto.createHash('sha256').update(buf).digest('hex');
  assert(sha === img.sha256, `hash mismatch ${img.path}`);
  assert(!hashes.has(sha), `duplicate bytes ${img.path}`);
  hashes.add(sha);
}

// Spot-check dimensions on a sample of files.
for (const img of manifest.images.filter((_, i) => i % 15 === 0)) {
  const meta = await sharp(path.join(root, img.path)).metadata();
  assert(meta.width === 1800 && meta.height === 2400, `dims ${img.path}`);
  assert(meta.format === 'webp', `format ${img.path}`);
}

function load(rel) {
  return JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'));
}

const marriage = load('initial_seeds/profiles.json');
const jobs = load('initial_seeds/jobs/profiles.json');
const bikes = load('initial_seeds/bikes/offers.json');
const rooms = load('initial_seeds/rooms/offers.json');
const help = load('initial_seeds/home_help/offers.json');

assert(marriage.profiles.length === 9, 'marriage profiles');
assert(jobs.profiles.length === 9, 'jobs profiles');
assert(bikes.offers.length === 9, 'bike offers');
assert(rooms.offers.length === 9, 'room offers');
assert(help.offers.length === 9, 'help offers');

for (const p of marriage.profiles) {
  assert(p.photoSlots?.length === 3, `${p.id} slots`);
}
for (const o of [...bikes.offers, ...rooms.offers, ...help.offers]) {
  assert(o.photoSlots?.length === 3, `${o.id} slots`);
}

const mCats = load('initial_seeds/categories.json').categories;
const jCats = load('initial_seeds/jobs/categories.json').categories;
assert(mCats.length === 3, 'marriage cats');
assert(jCats.length === 3, 'jobs cats');

if (errors.length) {
  console.error('VALIDATION FAILED:');
  for (const e of errors) console.error(' -', e);
  process.exit(1);
}
console.log('Sharp 3×3×3 bundle OK:', {
  images: hashes.size,
  miB: (manifest.counts.totalBytes / (1024 * 1024)).toFixed(2),
});
