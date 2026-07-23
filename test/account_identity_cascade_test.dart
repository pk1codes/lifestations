import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/identity_repository.dart';
import 'package:flut_marriage/services/media_upload_service.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/whatsapp_gate_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what IdentityRepository would persist remotely (no Firebase).
class _RecordingIdentityRepo extends IdentityRepository {
  _RecordingIdentityRepo(SharedPreferences prefs) : super(preferences: prefs);

  Identity? lastSaved;
  Identity? lastSynced;
  var syncCalls = 0;

  @override
  Future<void> save(Identity identity) async {
    lastSaved = identity;
    await super.save(identity);
  }

  @override
  Future<void> sync(Identity identity) async {
    syncCalls++;
    lastSynced = identity;
    // Skip Firestore — prove local + sync invocation only.
  }
}

void main() {
  test(
    'Account save cascade: photo + WA → prefs, digits strip, Me ready',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _RecordingIdentityRepo(prefs);
      final store = IdentityStore(prefs, repository: repo);

      expect(hasWhatsAppNumber(store.identity), isFalse);
      expect(store.completed, isFalse);

      const photo =
          'https://aaaa-4eee0.web.app/i/profile_photos%2Fu1%2Fidentity%2F0%2Fmedium.webp';

      await store.save(
        const Identity(
          userId: 'u1',
          displayName: '  Ravi  ',
          whatsappNumber: '+91 98765 43210',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          nativeLanguage: 'Hindi',
          photoUrls: [photo],
        ),
      );

      // Frontend store + prefs.
      expect(store.identity.displayName, 'Ravi');
      expect(store.identity.whatsappNumber, '919876543210');
      expect(store.identity.photoUrls.single, photo);
      expect(hasWhatsAppNumber(store.identity), isTrue);
      expect(store.completed, isTrue);
      expect(prefs.getString('identity_phone'), '919876543210');
      expect(prefs.getStringList('identity_photo_urls'), [photo]);
      expect(prefs.getString('identity_name'), 'Ravi');

      // Backend sync requested with same payload (vault + public user doc).
      expect(repo.syncCalls, 1);
      expect(repo.lastSynced?.whatsappNumber, '919876543210');
      expect(repo.lastSynced?.photoUrls.single, photo);
    },
  );

  test('phone verify does not wipe name/city prefs', () async {
    SharedPreferences.setMockInitialValues({
      'identity_name': 'Ravi',
      'identity_phone': '919876543210',
      'identity_city_id': 'mumbai',
      'identity_city_label': 'Mumbai',
      'identity_language': 'Hindi',
      'identity_phone_verified': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = _RecordingIdentityRepo(prefs);
    final store = IdentityStore(prefs, repository: repo);

    await store.savePhoneVerification(
      phoneVerified: true,
      whatsappNumber: '96590977001',
      dialCodePreference: '965',
    );

    expect(store.identity.displayName, 'Ravi');
    expect(store.identity.cityId, 'mumbai');
    expect(store.identity.nativeLanguage, 'Hindi');
    expect(store.identity.phoneVerified, isTrue);
    expect(store.identity.whatsappNumber, '96590977001');
    expect(prefs.getString('identity_name'), 'Ravi');
    expect(prefs.getString('identity_city_label'), 'Mumbai');
    expect(prefs.getBool('identity_phone_verified'), isTrue);
  });

  test('partial save with empty name keeps existing profile fields', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = IdentityStore(prefs, repository: _RecordingIdentityRepo(prefs));
    await store.save(
      const Identity(
        displayName: 'Ravi',
        whatsappNumber: '919876543210',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        nativeLanguage: 'Hindi',
      ),
    );
    await store.save(store.identity.copyWith(phoneVerified: true));
    expect(prefs.getString('identity_name'), 'Ravi');
    expect(store.identity.displayName, 'Ravi');
    expect(store.identity.phoneVerified, isTrue);
  });

  test('Identity CDN path uses profile_photos/{uid}/identity/{slot}', () {
    expect(
      mediaCdnUrl('profile_photos/u1/identity/0/medium.webp'),
      contains('/i/profile_photos'),
    );
    expect(
      mediaCdnUrl('profile_photos/u1/identity/0/medium.webp'),
      contains('identity'),
    );
  });

  test('WA gate: short number rejected; 8–15 digits accepted', () {
    expect(
      hasWhatsAppNumber(const Identity(whatsappNumber: '1234567')),
      isFalse,
    );
    expect(
      hasWhatsAppNumber(const Identity(whatsappNumber: '1234567890123456')),
      isFalse,
    );
    expect(
      hasWhatsAppNumber(const Identity(whatsappNumber: '9876543210')),
      isTrue,
    );
  });

  test(
    'Identity.isValid does not require photo; requires name+WA+city+language',
    () {
      expect(
        const Identity(
          displayName: 'Ravi',
          whatsappNumber: '9876543210',
          cityId: 'mumbai',
          nativeLanguage: 'Hindi',
        ).isValid,
        isTrue,
      );
      expect(
        const Identity(
          displayName: 'Ravi',
          whatsappNumber: '9876543210',
          cityId: 'mumbai',
          nativeLanguage: 'Hindi',
          photoUrls: ['https://cdn.example/a.webp'],
        ).isValid,
        isTrue,
      );
    },
  );
}
