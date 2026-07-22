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
  SafetyRepository? safety,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
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
                sheetContext.read<BlockStore>().block(ownerId);
                sheetContext.read<DiscoveryStore>().block(ownerId);
                final messenger = ScaffoldMessenger.of(sheetContext);
                Navigator.pop(sheetContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Blocked')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report post'),
              onTap: () async {
                await (safety ?? SafetyRepository()).report(
                  domain: domain,
                  targetId: targetId,
                  reason: 'other',
                );
                if (!sheetContext.mounted) return;
                final messenger = ScaffoldMessenger.of(sheetContext);
                Navigator.pop(sheetContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: const Text('Report underage / child safety'),
              onTap: () async {
                await (safety ?? SafetyRepository()).flagImage(
                  domain: domain,
                  targetId: targetId,
                  reason: 'child_safety',
                );
                if (!sheetContext.mounted) return;
                final messenger = ScaffoldMessenger.of(sheetContext);
                Navigator.pop(sheetContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Urgent report submitted')),
                );
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
