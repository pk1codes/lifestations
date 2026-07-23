import 'package:flutter/foundation.dart';

import '../models/discovery_card.dart';

/// Merges a Firestore `users/{uid}` map into local identity.
///
/// Photos and job posts rehydrate from their own remote paths on refresh.
/// Account metadata (name / city / language) must also come back from this doc
/// when local prefs were wiped by a partial phone-only save — without blanking
/// any field the user still has locally.
Identity mergeRemoteIdentity(Identity local, Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return local;

  final remoteName = (data['displayName'] as String?)?.trim() ?? '';
  final remoteCityId = (data['cityId'] as String?)?.trim() ?? '';
  final remoteCityLabel = (data['cityLabel'] as String?)?.trim() ?? '';
  final remoteLanguage = (data['nativeLanguage'] as String?)?.trim() ?? '';
  final remotePhotos = List<String>.from(
    data['photoUrls'] as List? ?? const <dynamic>[],
  ).map((url) => url.trim()).where((url) => url.isNotEmpty).toList();

  return local.copyWith(
    displayName: local.displayName.trim().isEmpty && remoteName.isNotEmpty
        ? remoteName
        : local.displayName,
    cityId: local.cityId.isEmpty && remoteCityId.isNotEmpty
        ? remoteCityId
        : local.cityId,
    cityLabel: local.cityLabel.isEmpty && remoteCityLabel.isNotEmpty
        ? remoteCityLabel
        : local.cityLabel,
    nativeLanguage: local.nativeLanguage.isEmpty && remoteLanguage.isNotEmpty
        ? remoteLanguage
        : local.nativeLanguage,
    photoUrls: remotePhotos.isNotEmpty && !listEquals(remotePhotos, local.photoUrls)
        ? remotePhotos
        : local.photoUrls,
  );
}

/// Prefer non-empty incoming profile strings; otherwise keep [existing].
String coalesceIdentityField(String incoming, String existing) {
  final next = incoming.trim();
  if (next.isNotEmpty) return next;
  return existing.trim();
}
