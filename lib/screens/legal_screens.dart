import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_bootstrap.dart';
import '../theme/app_theme.dart';

/// Legal / policy pages required by Google Play. The same wording is
/// published as static HTTPS pages under /legal/ on Firebase Hosting
/// (see web/legal/ and firebase/public/legal/). Keep both in sync and
/// bump [legalLastUpdated] whenever the wording changes.
const legalLastUpdated = '19 July 2026';

const _appName = 'Life Stations';
const _hostingOrigin = 'https://aaaa-4eee0.web.app';

class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

const privacyPolicySections = <LegalSection>[
  LegalSection(
    'What this app does',
    '$_appName is a discovery app for five life domains — Marriage, Jobs, '
        'Rooms, Bikes, and Home Help. You keep one private account and '
        'publish independent, privacy-redacted listing cards per domain.',
  ),
  LegalSection(
    'Information we collect',
    '• Account: phone number (for OTP sign-in), display name, city, '
        'native language, and a WhatsApp contact number you choose to add.\n'
        '• Listings: the text and photos you publish for a domain.\n'
        '• Activity: likes, blocks, reports, and share links you create.\n'
        '• Device: push-notification tokens, crash logs, and anonymized '
        'analytics events.\n'
        '• Self-attested trust flags (for example "ID+"). We do not collect '
        'or store government ID documents.',
  ),
  LegalSection(
    'How your information is used',
    '• Discovery cards show only redacted, non-contact information.\n'
        '• Your phone and WhatsApp numbers stay in a private vault and are '
        'revealed to another user only after mutual interest in the same '
        'domain and a verified phone session on both sides.\n'
        '• Push tokens send match and safety notifications.\n'
        '• Analytics and crash data keep the app reliable.',
  ),
  LegalSection(
    'Where data is stored',
    'Data is processed and stored on Google Firebase (Firestore database, '
        'Cloud Storage for photos, Firebase Authentication, Cloud '
        'Messaging, Analytics, and Crashlytics). Uploaded photos are '
        'compressed and screened by automated moderation before they '
        'appear publicly.',
  ),
  LegalSection(
    'What we never do',
    'We do not sell your personal data. We do not show your phone number '
        'on any public card. We do not use your photos for anything other '
        'than the listings you created.',
  ),
  LegalSection(
    'Sharing',
    'Public share links (/c/…) contain only the redacted card you chose '
        'to share — never contact details. Data processors are limited to '
        'Google Firebase services listed above.',
  ),
  LegalSection(
    'Retention & deletion',
    'Your data is kept while your account is active. You can delete your '
        'account and data at any time from Settings → Data & account '
        'deletion inside the app, or request deletion at '
        '$_hostingOrigin/legal/delete-account.html. Deletion requests are '
        'completed within 30 days.',
  ),
  LegalSection(
    'Age requirement',
    '$_appName is for adults aged 18 and above. Underage profiles are '
        'removed and can be reported from any card via Report → underage / '
        'child safety.',
  ),
  LegalSection(
    'Contact',
    'For privacy questions or requests, contact the support email listed '
        'on our Google Play store listing.',
  ),
];

const dataDeletionSections = <LegalSection>[
  LegalSection(
    'Delete inside the app (fastest)',
    'Settings → Data & account deletion → "Delete my account & data". '
        'This removes your account and associated data.',
  ),
  LegalSection(
    'What gets deleted',
    '• Your private account record (name, city, language, phone, WhatsApp '
        'number)\n'
        '• All listing cards you published in every domain\n'
        '• Your uploaded photos\n'
        '• Likes, blocks, share links, and push-notification tokens\n'
        '• Your sign-in account (you will be signed out everywhere)',
  ),
  LegalSection(
    'What may be retained',
    'Safety reports filed against or by your account may be retained in '
        'anonymized form for moderation and legal compliance. Crash and '
        'analytics data is anonymized and expires automatically.',
  ),
  LegalSection(
    'Request deletion without the app',
    'If you uninstalled the app, request deletion at '
        '$_hostingOrigin/legal/delete-account.html or email the support '
        'address on our Google Play listing from the phone number\'s '
        'registered account. Requests are completed within 30 days.',
  ),
];

const termsSections = <LegalSection>[
  LegalSection(
    'Community terms',
    'Use truthful, respectful information. Harassment, exploitation, '
        'illegal services, impersonation, and sharing another person\'s '
        'private data are prohibited.',
  ),
  LegalSection(
    'Trust labels',
    'Trust labels are self-attested and are not government or '
        'cryptographic verification. Use judgment before meeting, hiring, '
        'renting, or paying.',
  ),
  LegalSection(
    'Moderation',
    'Listings pass automated image and text moderation and may be removed. '
        'Repeated or serious violations lead to account termination.',
  ),
];

class LegalPageScreen extends StatelessWidget {
  const LegalPageScreen._({
    required this.title,
    required this.sections,
    this.trailing,
  });

  const LegalPageScreen.privacy({Key? key})
    : this._(title: 'Privacy policy', sections: privacyPolicySections);

  const LegalPageScreen.terms({Key? key})
    : this._(title: 'Community terms', sections: termsSections);

  const LegalPageScreen.dataDeletion({Key? key})
    : this._(
        title: 'Data & account deletion',
        sections: dataDeletionSections,
        trailing: const _DeleteAccountCard(),
      );

  final String title;
  final List<LegalSection> sections;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.cream.withValues(alpha: .95),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Last updated: $legalLastUpdated',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...[
            Text(section.heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(section.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
          ],
          ?trailing,
        ],
      ),
    );
  }
}

class _DeleteAccountCard extends StatefulWidget {
  const _DeleteAccountCard();

  @override
  State<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends State<_DeleteAccountCard> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account & data?'),
        content: const Text(
          'This permanently removes your account, listings, photos, likes, '
          'and contact details. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    String message = 'Local data cleared.';
    try {
      if (FirebaseBootstrap.ready &&
          FirebaseAuth.instance.currentUser != null) {
        await FirebaseFunctions.instance
            .httpsCallable('deleteAccount')
            .call<void>();
        await FirebaseAuth.instance.signOut();
        message = 'Your account and data were deleted.';
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {
      message =
          'Could not reach the server. Local data was cleared; use the web '
          'form to complete server-side deletion.';
      unawaited(SharedPreferences.getInstance().then((prefs) => prefs.clear()));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha: .06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete my account & data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Removes everything listed above. You will be signed out '
              'immediately.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _busy ? null : _delete,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete my account & data'),
            ),
          ],
        ),
      ),
    );
  }
}
