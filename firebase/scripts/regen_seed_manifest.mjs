#!/usr/bin/env node
/**
 * Regenerates initial_seeds/manifest.json from the images currently on disk.
 *
 * Run this after replacing seed photos so `npm run validate:333` and the Flutter
 * seed_contract_test stay green:
 *
 *   cd firebase/scripts && npm run seed:manifest
 *
 * Expects the canonical 5 domains × 9 cards × 3 slots = 135 WebPs at:
 *   initial_seeds/photos/marriage_{card}_{slot}.webp
 *   initial_seeds/jobs/photos/jobs_{card}_{slot}.webp
 *   initial_seeds/rooms/photos/rooms_{card}_{slot}.webp
 *   initial_seeds/bikes/photos/bikes_{card}_{slot}.webp
 *   initial_seeds/home_help/photos/home_help_{card}_{slot}.webp
 */
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../../');

const domains = [
  { id: 'marriage', dir: 'initial_seeds/photos' },
  { id: 'jobs', dir: 'initial_seeds/jobs/photos' },
  { id: 'rooms', dir: 'initial_seeds/rooms/photos' },
  { id: 'bikes', dir: 'initial_seeds/bikes/photos' },
  { id: 'home_help', dir: 'initial_seeds/home_help/photos' },
];

const errors = [];
const images = [];
const hashes = new Set();
const dimensionSet = new Set();
let totalBytes = 0;

for (const domain of domains) {
  const absDir = path.join(root, domain.dir);
  if (!fs.existsSync(absDir)) {
    errors.push(`missing directory ${domain.dir}`);
    continue;
  }
  const files = fs
    .readdirSync(absDir)
    .filter((name) => name.endsWith('.webp'))
    .map((name) => {
      const match = name.match(/_(\d+)_(\d+)\.webp$/);
      return match
        ? { name, cardIndex: Number(match[1]), slot: Number(match[2]) }
        : { name, cardIndex: NaN, slot: NaN };
    })
    .sort((a, b) => a.cardIndex - b.cardIndex || a.slot - b.slot);

  if (files.length !== 27) {
    errors.push(`${domain.id}: expected 27 images, found ${files.length}`);
  }

  for (const file of files) {
    if (Number.isNaN(file.cardIndex) || Number.isNaN(file.slot)) {
      errors.push(`${domain.id}/${file.name}: cannot parse card/slot`);
      continue;
    }
    const rel = `${domain.dir}/${file.name}`;
    const buf = fs.readFileSync(path.join(root, rel));
    const sha = crypto.createHash('sha256').update(buf).digest('hex');
    if (hashes.has(sha)) errors.push(`duplicate bytes ${rel}`);
    hashes.add(sha);
    totalBytes += buf.length;
    // eslint-disable-next-line no-await-in-loop
    const meta = await sharp(buf).metadata();
    if (meta.format !== 'webp') errors.push(`${rel}: not webp (${meta.format})`);
    dimensionSet.add(`${meta.width}x${meta.height}`);
    images.push({
      path: rel,
      sha256: sha,
      bytes: buf.length,
      width: meta.width,
      height: meta.height,
      domain: domain.id,
      cardIndex: file.cardIndex,
      slot: file.slot,
    });
  }
}

if (dimensionSet.size > 1) {
  errors.push(`images are not uniform: ${[...dimensionSet].join(', ')}`);
}

if (errors.length) {
  console.error('MANIFEST REGEN FAILED:');
  for (const e of errors) console.error(' -', e);
  process.exit(1);
}

const [width, height] = [...dimensionSet][0].split('x').map(Number);
const manifest = {
  version: 1,
  synthetic: true,
  dimensions: { width, height },
  counts: {
    cards: images.length / 3,
    images: images.length,
    uniqueSha256: hashes.size,
    totalBytes,
  },
  domains: domains.map((domain) => ({
    id: domain.id,
    cards: images.filter((img) => img.domain === domain.id).length / 3,
    images: images.filter((img) => img.domain === domain.id).length,
  })),
  images,
};

const out = path.join(root, 'initial_seeds/manifest.json');
fs.writeFileSync(out, `${JSON.stringify(manifest, null, 2)}\n`);
console.log('Regenerated initial_seeds/manifest.json:', {
  images: manifest.counts.images,
  dimensions: `${width}x${height}`,
  miB: (totalBytes / (1024 * 1024)).toFixed(2),
});
if (width !== 1800 || height !== 2400) {
  console.warn(
    `NOTE: dimensions are ${width}x${height}, not 1800x2400. Update the ` +
      'expectation in test/seed_contract_test.dart and validate_sharp_333_bundle.mjs.',
  );
}
