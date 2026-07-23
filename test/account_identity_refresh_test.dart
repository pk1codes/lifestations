import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/identity_merge.dart';
import 'package:flut_marriage/services/identity_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records sync without touching Firestore.
class _Repo extends IdentityRepository {
  _Repo(SharedPreferences prefs) : super(preferences: prefs);

  Identity? lastSynced;
  var syncCalls = 0;

  @override
  Future<void> sync(Identity identity) async {
    syncCalls++;
    lastSynced = identity;
  }
}

void main() {
  const photo =
      'https://aaaa-4eee0.web.app/i/profile_photos%2Fu1%2Fidentity%2F0%2Fmedium.webp';

  group('mergeRemoteIdentity — refresh metadata gap', () {
    test('photos local + name only remote → name restored (user bug)', () {
      // Refresh used to hydrate photos only; name vanished while avatar stayed.
      const local = Identity(
        photoUrls: [photo],
        phoneVerified: true,
        whatsappNumber: '919876543210',
      );
      final merged = mergeRemoteIdentity(local, {
        'displayName': 'Ravi',
        'cityId': 'mumbai',
        'cityLabel': 'Mumbai',
        'nativeLanguage': 'Hindi',
        'photoUrls': [photo],
      });
      expect(merged.displayName, 'Ravi');
      expect(merged.cityId, 'mumbai');
      expect(merged.cityLabel, 'Mumbai');
      expect(merged.nativeLanguage, 'Hindi');
      expect(merged.photoUrls, [photo]);
      expect(merged.phoneVerified, isTrue);
      expect(merged.whatsappNumber, '919876543210');
    });

    test('does not blank local name when remote omits displayName', () {
      const local = Identity(
        displayName: 'Ravi',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        nativeLanguage: 'Hindi',
        photoUrls: [photo],
      );
      final merged = mergeRemoteIdentity(local, {
        'photoUrls': [photo],
        'boostUntil': 'ignored',
      });
      expect(merged.displayName, 'Ravi');
      expect(merged.cityLabel, 'Mumbai');
    });

    test('keeps local name when remote has a different name', () {
      const local = Identity(displayName: 'Local Name', photoUrls: [photo]);
      final merged = mergeRemoteIdentity(local, {
        'displayName': 'Remote Name',
        'photoUrls': [photo],
      });
      expect(merged.displayName, 'Local Name');
    });

    test('fills photos from remote when local list empty', () {
      const local = Identity(displayName: 'Ravi');
      final merged = mergeRemoteIdentity(local, {
        'displayName': 'Ravi',
        'photoUrls': [photo],
      });
      expect(merged.photoUrls, [photo]);
    });

    test('null / empty remote leaves local unchanged', () {
      const local = Identity(displayName: 'Ravi', photoUrls: [photo]);
      expect(mergeRemoteIdentity(local, null), same(local));
      expect(mergeRemoteIdentity(local, const {}), same(local));
    });
  });

  group('IdentityStore refresh durability', () {
    test('phone-only verify does not wipe name/city/language prefs', () async {
      SharedPreferences.setMockInitialValues({
        'identity_name': 'Ravi',
        'identity_phone': '919876543210',
        'identity_city_id': 'mumbai',
        'identity_city_label': 'Mumbai',
        'identity_language': 'Hindi',
        'identity_photo_urls': [photo],
        'identity_phone_verified': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(prefs, repository: _Repo(prefs));

      await store.savePhoneVerification(
        phoneVerified: true,
        whatsappNumber: '96590977001',
        dialCodePreference: '965',
      );

      expect(prefs.getString('identity_name'), 'Ravi');
      expect(prefs.getString('identity_city_id'), 'mumbai');
      expect(prefs.getString('identity_city_label'), 'Mumbai');
      expect(prefs.getString('identity_language'), 'Hindi');
      expect(prefs.getStringList('identity_photo_urls'), [photo]);
      expect(prefs.getBool('identity_phone_verified'), isTrue);
      expect(prefs.getString('identity_phone'), '96590977001');
    });

    test('partial save keeps profile when only phoneVerified flips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(prefs, repository: _Repo(prefs));
      await store.save(
        const Identity(
          displayName: 'Ravi',
          whatsappNumber: '919876543210',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          nativeLanguage: 'Hindi',
          photoUrls: [photo],
        ),
      );
      await store.save(store.identity.copyWith(phoneVerified: true));
      expect(prefs.getString('identity_name'), 'Ravi');
      expect(prefs.getStringList('identity_photo_urls'), [photo]);
    });

    test(
      'IdentityRepository.save never blanks existing name with empty payload',
      () async {
        SharedPreferences.setMockInitialValues({
          'identity_name': 'Ravi',
          'identity_city_id': 'mumbai',
          'identity_city_label': 'Mumbai',
          'identity_language': 'Hindi',
          'identity_photo_urls': [photo],
          'identity_phone': '919876543210',
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = _Repo(prefs);
        await repo.save(
          const Identity(
            phoneVerified: true,
            whatsappNumber: '96590977001',
            photoUrls: [photo],
          ),
        );
        expect(prefs.getString('identity_name'), 'Ravi');
        expect(prefs.getString('identity_city_label'), 'Mumbai');
        expect(prefs.getStringList('identity_photo_urls'), [photo]);
        expect(prefs.getBool('identity_phone_verified'), isTrue);
      },
    );

    test('new IdentityStore reload keeps name after full save', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(prefs, repository: _Repo(prefs));
      await store.save(
        const Identity(
          displayName: 'Ravi',
          whatsappNumber: '919876543210',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          nativeLanguage: 'Hindi',
          photoUrls: [photo],
          phoneVerified: true,
        ),
      );

      final reloaded = IdentityStore(prefs, repository: _Repo(prefs));
      expect(reloaded.identity.displayName, 'Ravi');
      expect(reloaded.identity.cityLabel, 'Mumbai');
      expect(reloaded.identity.nativeLanguage, 'Hindi');
      expect(reloaded.identity.photoUrls, [photo]);
      expect(reloaded.identity.phoneVerified, isTrue);
    });
  });

  test('coalesceIdentityField prefers non-empty incoming', () {
    expect(coalesceIdentityField('  Ravi  ', 'Old'), 'Ravi');
    expect(coalesceIdentityField('  ', 'Old'), 'Old');
    expect(coalesceIdentityField('', ''), '');
  });
}
