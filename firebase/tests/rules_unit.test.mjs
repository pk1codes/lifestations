/**
 * Firestore + Storage rules unit tests (emulator).
 *
 *   cd firebase/tests && npm install && npm run test:rules
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

const firestoreRules = fs.readFileSync(
  path.join(root, 'firestore.rules'),
  'utf8',
);
const storageRules = fs.readFileSync(path.join(root, 'storage.rules'), 'utf8');

function jobsOfferDoc(ownerId, extras = {}) {
  return {
    id: extras.id ?? 'jobs_offer_1',
    domainId: 'jobs',
    ownerId,
    title: 'Driver',
    subtitle: 'Prefer not to say',
    cityId: 'mumbai',
    cityLabel: 'Mumbai',
    categoryTags: ['Driver'],
    photoUrls: ['https://cdn.example/j.webp'],
    role: 'seek',
    attributes: {
      tradeId: 'Driver',
      salaryBand: 'Prefer not to say',
    },
    active: true,
    verified: false,
    ...extras,
  };
}

function publicCardDoc(ownerId, domain = 'jobs') {
  return {
    slug: `${domain}_abcdefghij`,
    active: true,
    ownerId,
    domain,
    sourceId: 'jobs_offer_1',
    headline: 'Driver',
    locationLabel: 'Mumbai',
    detailLine: 'Prefer not to say',
    sideLabel: 'I have',
    categoryTags: ['Driver'],
    photoUrl: 'https://cdn.example/j.webp',
    verified: false,
    promoted: false,
  };
}

const failures = [];
let passed = 0;

async function test(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`  ok  ${name}`);
  } catch (error) {
    failures.push({ name, error });
    console.error(`  FAIL ${name}`);
    console.error(`       ${error && error.message ? error.message : error}`);
  }
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-life-stations',
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });

  const run = async (name, fn) => {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
    await test(name, fn);
  };

  console.log('Rules unit tests (emulator)');

  await run('peer cannot read another user contact vault', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/alice/private/contact').set({
        whatsappNumber: '919876543210',
      });
    });
    const bob = testEnv.authenticatedContext('bob');
    await assertFails(bob.firestore().doc('users/alice/private/contact').get());
  });

  await run('owner can read own contact vault', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/alice/private/contact').set({
        whatsappNumber: '919876543210',
      });
    });
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(
      alice.firestore().doc('users/alice/private/contact').get(),
    );
  });

  await run('Jobs offer create succeeds for owner', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(
      alice
        .firestore()
        .doc('domains/jobs/offers/jobs_offer_1')
        .set(jobsOfferDoc('alice')),
    );
  });

  await run('Jobs offer rejects contact smuggling in attributes', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(
      alice
        .firestore()
        .doc('domains/jobs/offers/jobs_bad')
        .set(
          jobsOfferDoc('alice', {
            id: 'jobs_bad',
            attributes: {
              tradeId: 'Driver',
              salaryBand: 'Prefer not to say',
              whatsappNumber: '919999999999',
            },
          }),
        ),
    );
  });

  await run('Jobs offer rejects top-level phone', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(
      alice
        .firestore()
        .doc('domains/jobs/offers/jobs_phone')
        .set({
          ...jobsOfferDoc('alice', { id: 'jobs_phone' }),
          phone: '919999999999',
        }),
    );
  });

  await run('public card create with allowlist succeeds', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(
      alice
        .firestore()
        .doc('domains/jobs/public_cards/jobs_abcdefghij')
        .set(publicCardDoc('alice')),
    );
  });

  await run('public card rejects free-form bio', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(
      alice
        .firestore()
        .doc('domains/jobs/public_cards/jobs_abcdefghij')
        .set({
          ...publicCardDoc('alice'),
          bio: 'call me',
        }),
    );
  });

  await run('stranger cannot write another users public card', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(
      alice
        .firestore()
        .doc('domains/jobs/public_cards/jobs_abcdefghij')
        .set(publicCardDoc('alice')),
    );
    const bob = testEnv.authenticatedContext('bob');
    await assertFails(
      bob
        .firestore()
        .doc('domains/jobs/public_cards/jobs_abcdefghij')
        .set(publicCardDoc('bob')),
    );
  });

  await run('storage docs path: non-owner cannot read RC', async () => {
    const pathName =
      'media/alice/bikes/bike1/docs/rc/proof.webp';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const ref = ctx.storage().ref(pathName);
      await ref.put(Buffer.from('fake-image-bytes'), {
        contentType: 'image/webp',
      });
    });
    const bob = testEnv.authenticatedContext('bob');
    await assertFails(bob.storage().ref(pathName).getDownloadURL());
  });

  await run('storage docs path: owner can read RC', async () => {
    const pathName =
      'media/alice/bikes/bike1/docs/rc/proof.webp';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(pathName).put(Buffer.from('fake-image-bytes'), {
        contentType: 'image/webp',
      });
    });
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(alice.storage().ref(pathName).getMetadata());
  });

  await testEnv.cleanup();

  console.log(`\nRules unit: ${passed} passed, ${failures.length} failed`);
  if (failures.length) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
