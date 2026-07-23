import 'package:flutter/material.dart';

enum AppDomainId { marriage, jobs, rooms, bikes, homeHelp, kuwaitJobs }

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

  String get slug => switch (id) {
    AppDomainId.homeHelp => 'home_help',
    AppDomainId.kuwaitJobs => 'kuwait_jobs',
    _ => id.name,
  };
  String get collection => storageKind == DomainStorageKind.profiles
      ? 'domains/$slug/profiles'
      : 'domains/$slug/offers';

  /// Soft wash for backgrounds / avatars — same hue, low opacity.
  Color get softColor => color.withValues(alpha: .14);
  Color get softSurface => Color.alphaBlend(softColor, const Color(0xFFFFF8F3));
}

abstract final class AppDomains {
  /// Kuwait Jobs — Gulf teal. Oilfield / camp roles (Available / Wanted).
  static const kuwaitJobs = DomainPolicy(
    id: AppDomainId.kuwaitJobs,
    label: 'Kuwait Jobs',
    frequency: 88.8,
    color: Color(0xFF0F766E),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.face,
    maxProfiles: 5,
    minPhotos: 1,
    maxPhotos: 3,
    roles: <String>['seek', 'offer'],
    enabled: true,
  );

  /// Marriage — warm rose (love).
  static const marriage = DomainPolicy(
    id: AppDomainId.marriage,
    label: 'Marriage',
    frequency: 91.2,
    color: Color(0xFFBE185D),
    storageKind: DomainStorageKind.profiles,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.face,
    maxProfiles: 1,
    minPhotos: 1,
    maxPhotos: 3,
    roles: <String>[],
    enabled: true,
  );

  /// Jobs — deep work blue. Multi listing (I have / I need per trade).
  static const jobs = DomainPolicy(
    id: AppDomainId.jobs,
    label: 'Jobs',
    frequency: 94.5,
    color: Color(0xFF1D4ED8),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.face,
    maxProfiles: 5,
    minPhotos: 1,
    maxPhotos: 3,
    roles: <String>['seek', 'offer'],
    enabled: true,
  );

  /// Rooms — terracotta / home wood.
  static const rooms = DomainPolicy(
    id: AppDomainId.rooms,
    label: 'Rooms',
    frequency: 98.1,
    color: Color(0xFFC2410C),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.asset,
    mediaPolicy: MediaPolicy.asset,
    maxProfiles: 5,
    minPhotos: 2,
    maxPhotos: 8,
    roles: <String>['have'],
    enabled: true,
  );

  /// Bikes — forest green (wheels / road).
  static const bikes = DomainPolicy(
    id: AppDomainId.bikes,
    label: 'Bikes',
    frequency: 101.7,
    color: Color(0xFF15803D),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.asset,
    mediaPolicy: MediaPolicy.asset,
    maxProfiles: 5,
    minPhotos: 4,
    maxPhotos: 4,
    roles: <String>['lend'],
    enabled: true,
  );

  /// Home Help — violet (care).
  static const homeHelp = DomainPolicy(
    id: AppDomainId.homeHelp,
    label: 'Home Help',
    frequency: 107.7,
    color: Color(0xFF7C3AED),
    storageKind: DomainStorageKind.offers,
    subject: OfferSubject.person,
    mediaPolicy: MediaPolicy.either,
    maxProfiles: 5,
    minPhotos: 0,
    maxPhotos: 4,
    roles: <String>['need', 'have'],
    enabled: true,
  );

  /// Dial order: Kuwait Jobs first, then the original five.
  static const all = <DomainPolicy>[
    kuwaitJobs,
    marriage,
    jobs,
    rooms,
    bikes,
    homeHelp,
  ];

  static DomainPolicy byId(AppDomainId id) =>
      all.firstWhere((domain) => domain.id == id);
}
