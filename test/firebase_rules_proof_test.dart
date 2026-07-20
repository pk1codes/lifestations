import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rules-source proofs only — no Flutter lib imports (safe while app agent works).
void main() {
  late String firestoreRules;
  late String storageRules;
  late String functionsSrc;

  setUpAll(() {
    firestoreRules = File('firebase/firestore.rules').readAsStringSync();
    storageRules = File('firebase/storage.rules').readAsStringSync();
    functionsSrc = File('firebase/functions/index.js').readAsStringSync();
  });

  group('RULES: public profiles strip contact', () {
    test('validProfile requires noPublicContact', () {
      final fn = firestoreRules
          .split('function validProfile')[1]
          .split('function validDomainEnvelope')[0];
      expect(fn.contains('noPublicContact(d)'), isTrue);
      expect(fn.contains('d.name.size() <= 128'), isTrue);
      expect(fn.contains('d.age is int'), isTrue);
    });

    test('contact vault is owner-only; mutual unlock is callable-side', () {
      final vault = firestoreRules
          .split('match /private/{docId}')[1]
          .split('match /blocks')[0];
      expect(vault.contains('allow read: if isOwner(userId);'), isTrue);
      expect(vault.contains('mutualLike(userId)'), isFalse);
      expect(firestoreRules.contains('function mutualLikeInDomain'), isTrue);
      expect(functionsSrc.contains('exports.unlockContact'), isTrue);
      expect(functionsSrc.contains('exports.claimActionThrottle'), isTrue);
    });

    test('rate_limits collection caps hits at 10', () {
      expect(firestoreRules.contains('match /rate_limits/{userId}'), isTrue);
      expect(
        firestoreRules.contains('request.resource.data.hits <= 10'),
        isTrue,
      );
    });

    test('image_flags are create-only / unreadable', () {
      expect(firestoreRules.contains('match /image_flags/{flagId}'), isTrue);
      final block = firestoreRules
          .split('match /image_flags/{flagId}')[1]
          .split('match /waitlists')[0];
      expect(block.contains('allow read: if false;'), isTrue);
      expect(block.contains('allow update, delete: if false;'), isTrue);
    });
  });

  group('RULES: offers and likes', () {
    test('offers reject contact and document URL smuggling', () {
      final offerFn = firestoreRules
          .split('function validOffer')[1]
          .split('function validPublicCard')[0];
      expect(offerFn.contains("!('whatsappNumber' in d)"), isTrue);
      expect(offerFn.contains("!('telegramHandle' in d)"), isTrue);
      expect(offerFn.contains("!('rcUrl' in d.attributes)"), isTrue);
      expect(offerFn.contains("!('insuranceUrl' in d.attributes)"), isTrue);
      expect(offerFn.contains("!('phone' in d.attributes)"), isTrue);
    });

    test('like snapshots forbid contact fields', () {
      final fn = firestoreRules
          .split('function validLikeDoc')[1]
          .split('function validImageFlag')[0];
      expect(fn.contains("!(('whatsappNumber' in d.snapshot))"), isTrue);
      expect(fn.contains("!(('telegramHandle' in d.snapshot))"), isTrue);
    });

    test('public cards forbid name/bio/phone/contact and use hasOnly', () {
      final fn = firestoreRules
          .split('function validPublicCard')[1]
          .split('function publicCardImmutable')[0];
      expect(fn.contains('keys().hasOnly(['), isTrue);
      expect(fn.contains("!('name' in d)"), isTrue);
      expect(fn.contains("!('bio' in d)"), isTrue);
      expect(fn.contains("!('phone' in d)"), isTrue);
      expect(fn.contains("!('whatsappNumber' in d)"), isTrue);
      expect(fn.contains("!('displayName' in d)"), isTrue);
      expect(fn.contains("!('title' in d)"), isTrue);
      expect(firestoreRules.contains('publicCardImmutable'), isTrue);
      expect(fn.contains("'rcUrl'"), isTrue);
      expect(fn.contains("'insuranceUrl'"), isTrue);
    });

    test('public card writes are domain-scoped and identifiers immutable', () {
      final legacy = firestoreRules
          .split('match /public_cards/{slug}')[1]
          .split('match /domains/{domainId}')[0];
      expect(
        legacy.contains('allow create, update, delete: if false;'),
        isTrue,
      );
      final immutable = firestoreRules
          .split('function publicCardImmutable')[1]
          .split('function validLikeDoc')[0];
      expect(immutable.contains('ownerId == resource.data.ownerId'), isTrue);
      expect(immutable.contains('domain == resource.data.domain'), isTrue);
      expect(immutable.contains('slug == resource.data.slug'), isTrue);
      expect(immutable.contains('sourceId == resource.data.sourceId'), isTrue);
      expect(firestoreRules.contains('match /domains/{domainId}'), isTrue);
    });
  });

  group('STORAGE: RC/insurance owner-only', () {
    test('docs path is owner-only read under 5 MiB image MIME', () {
      expect(storageRules.contains('5 * 1024 * 1024'), isTrue);
      expect(storageRules.contains("image/(webp|jpeg|jpg|png)"), isTrue);
      final docs = storageRules
          .split(
            'match /media/{userId}/{domainId}/{offerId}/docs/{docName}/{fileName}',
          )[1]
          .split('match /verify_staging')[0];
      expect(
        docs.contains('allow read: if isSignedIn() && isOwner(userId);'),
        isTrue,
      );
      expect(docs.contains("docName in ['rc', 'insurance']"), isTrue);
    });
  });

  group('FUNCTIONS: required exports', () {
    test('signed-in client writes require Auth (App Check optional in testing)', () {
      expect(firestoreRules.contains('request.auth != null'), isTrue);
      expect(storageRules.contains('request.auth != null'), isTrue);
      // App Check re-enforcement is deferred until providers are verified.
      expect(firestoreRules.contains('request.app != null'), isFalse);
      expect(storageRules.contains('request.app != null'), isFalse);
    });

    test('callable throttles and unlock enforce App Check', () {
      expect(functionsSrc.contains('enforceAppCheck: true'), isTrue);
    });

    test('exports and throttle constants present', () {
      expect(functionsSrc.contains('exports.onReportCreated'), isTrue);
      expect(functionsSrc.contains('exports.onImageFlagCreated'), isTrue);
      expect(functionsSrc.contains('exports.checkFeedThrottle'), isTrue);
      expect(functionsSrc.contains('exports.claimActionThrottle'), isTrue);
      expect(functionsSrc.contains('exports.onInboundLikeCreated'), isTrue);
      expect(functionsSrc.contains('exports.unlockContact'), isTrue);
      expect(functionsSrc.contains('maxHits: 10'), isTrue);
      expect(functionsSrc.contains('windowMs: 30_000'), isTrue);
      expect(functionsSrc.contains('flut_likes_high'), isTrue);
    });
  });
}
