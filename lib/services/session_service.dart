import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_stores.dart';
import '../state/domain_profile_stores.dart';
import 'firebase_bootstrap.dart';
import 'owned_listing_cache.dart';

/// Ends the local session (Google-style Sign out). Posts / profile stay on the
/// phone-linked Firebase account — verify the same number to restore them.
Future<void> signOutLocalSession(BuildContext context) async {
  final identity = context.read<IdentityStore>();
  final likes = context.read<LikesStore>();
  final media = context.read<OwnedListingCache>();
  final marriage = context.read<ProfileStore>();
  final jobs = context.read<JobsOfferStore>();
  final kuwaitJobs = context.read<KuwaitJobsOfferStore>();
  final rooms = context.read<RoomsOfferStore>();
  final bikes = context.read<BikesOfferStore>();
  final homeHelp = context.read<HomeHelpOfferStore>();

  likes.resetLocal();
  await identity.clear();
  marriage.clearLocal();
  jobs.clearAllOffers();
  kuwaitJobs.clearAllOffers();
  rooms.clearAllOffers();
  bikes.clearAllOffers();
  homeHelp.clearAllOffers();
  await media.clearAll();

  if (FirebaseBootstrap.ready) {
    try {
      await FirebaseAuth.instance.signOut();
      final user = await FirebaseBootstrap.ensureSignedIn();
      if (context.mounted) {
        await identity.bindUserId(user.uid);
      }
    } catch (_) {
      // Local session is already cleared; anonymous re-auth can retry later.
    }
  }
}
