import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_domain.dart';
import '../../services/safety_repository.dart';
import '../../state/app_stores.dart';
import '../../state/domain_profile_stores.dart';

Future<void> showSafetySheet(
  BuildContext context, {
  required AppDomainId domain,
  required String targetId,
  required String ownerId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block'),
              subtitle: const Text('Remove from every feed immediately'),
              onTap: () {
                context.read<BlockStore>().block(ownerId);
                context.read<DiscoveryStore>().block(ownerId);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report listing'),
              onTap: () async {
                await SafetyRepository().report(
                  domain: domain,
                  targetId: targetId,
                  reason: 'other',
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: const Text('Report underage / child safety'),
              onTap: () async {
                await SafetyRepository().flagImage(
                  domain: domain,
                  targetId: targetId,
                  reason: 'child_safety',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Urgent report submitted')),
                  );
                }
              },
            ),
            const ListTile(
              leading: Icon(Icons.gavel_outlined),
              title: Text('Community standards'),
              subtitle: Text('Respect, consent, truth, and no harassment.'),
            ),
          ],
        ),
      ),
    ),
  );
}
