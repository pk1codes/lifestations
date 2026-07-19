import 'package:flutter/material.dart';

enum AppDomainId { marriage, jobs, rooms, bikes, homeHelp }

enum DomainStorageKind { profiles, offers }

enum OfferSubject { person, asset }

enum MediaPolicy { face, asset, either }

@immutable
class DomainPolicy {
  const DomainPolicy({
    required this.id,
    required this.label,
    required this.frequency,
    required this.color,
    required this.storageKind,
    required this.subject,
    required this.mediaPolicy,
    required this.maxProfiles,
    required this.minPhotos,
    required this.maxPhotos,
    required this.roles,
    required this.enabled,
  });

  final AppDomainId id;
  final String label;
  final double frequency;
  final Color color;
  final DomainStorageKind storageKind;
  final OfferSubject subject;
  final MediaPolicy mediaPolicy;
  final int maxProfiles;
  final int minPhotos;
  final int maxPhotos;
  final List<String> roles;
  final bool enabled;

  String get slug => id == AppDomainId.homeHelp ? 'home_help' : id.name;
  String get collection => storageKind == DomainStorageKind.profiles
      ? 'domains/$slug/profiles'
      : 'domains/$slug/offers';
}

abstract final class AppDomains {
  static const marriage = DomainPolicy(
    id: AppDomainId.marriage,
    label: 'Marriage',
    frequency: 91.2,
    color: Color(0xFF9B3B5A),
    storageKind: DomainStorageKind.profiles,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.face,
    maxProfiles: 1,
    minPhotos: 1,
    maxPhotos: 3,
    roles: <String>[],
    enabled: true,
  );
  static const jobs = DomainPolicy(
    id: AppDomainId.jobs,
    label: 'Jobs',
    frequency: 94.5,
    color: Color(0xFF229ED9),
    storageKind: DomainStorageKind.profiles,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.face,
    maxProfiles: 1,
    minPhotos: 1,
    maxPhotos: 3,
    roles: <String>['seek', 'offer'],
    enabled: true,
  );
  static const rooms = DomainPolicy(
    id: AppDomainId.rooms,
    label: 'Rooms',
    frequency: 98.1,
    color: Color(0xFFD4A373),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.asset,
    mediaPolicy: MediaPolicy.asset,
    maxProfiles: 5,
    minPhotos: 2,
    maxPhotos: 8,
    roles: <String>['have'],
    enabled: true,
  );
  static const bikes = DomainPolicy(
    id: AppDomainId.bikes,
    label: 'Bikes',
    frequency: 101.7,
    color: Color(0xFF5B7C5A),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.asset,
    mediaPolicy: MediaPolicy.asset,
    maxProfiles: 5,
    minPhotos: 4,
    maxPhotos: 4,
    roles: <String>['lend'],
    enabled: true,
  );
  static const homeHelp = DomainPolicy(
    id: AppDomainId.homeHelp,
    label: 'Home Help',
    frequency: 107.7,
    color: Color(0xFF2A9D8F),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.either,
    maxProfiles: 3,
    minPhotos: 0,
    maxPhotos: 4,
    roles: <String>['need', 'have'],
    enabled: true,
  );

  static const all = <DomainPolicy>[marriage, jobs, rooms, bikes, homeHelp];

  static DomainPolicy byId(AppDomainId id) =>
      all.firstWhere((domain) => domain.id == id);
}
