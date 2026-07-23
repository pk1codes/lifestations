import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const _values = <String, Map<String, String>>{
    'en': <String, String>{
      'browse': 'Browse',
      'likes': 'Likes',
      'me': 'Me',
      'guide': 'Guide',
      'comingSoon': 'Coming soon',
      'connect': 'Connect',
      'pass': 'Skip',
      'like': 'Interested',
      'iHave': 'I have',
      'iNeed': 'I need',
      'postMarriage': 'Looking for marriage',
      'postJobs': 'I need work / I have work',
      'postKuwaitJobs': 'Available / Wanted',
      'postRooms': 'I have a room',
      'postBikes': 'Lend my bike',
      'postHomeHelp': 'I need help / I can help',
      'nearby': 'nearby',
      'more': 'More',
      'report': 'Report',
      'block': 'Block',
      'share': 'Share',
      'filter': 'Filters',
      'boost': 'Boost',
      'match': 'Both interested',
      'empty': 'You reached the end for now.',
      'safety': 'Safety',
      'refresh': 'Refresh today',
      'verifyPhone': 'Verify phone to connect',
    },
    'hi': <String, String>{
      'browse': 'खोजें',
      'likes': 'पसंद',
      'me': 'मैं',
      'guide': 'मार्गदर्शिका',
      'comingSoon': 'जल्द आ रहा है',
      'connect': 'संपर्क करें',
      'pass': 'छोड़ें',
      'like': 'रुचि है',
      'iHave': 'मेरे पास है',
      'iNeed': 'मुझे चाहिए',
      'postMarriage': 'शादी के लिए',
      'postJobs': 'काम चाहिए / काम है',
      'postKuwaitJobs': 'उपलब्ध / चाहिए',
      'postRooms': 'कमरा है',
      'postBikes': 'बाइक किराए पर दें',
      'postHomeHelp': 'मदद चाहिए / मदद कर सकता हूँ',
      'nearby': 'पास में',
      'more': 'और',
      'report': 'रिपोर्ट करें',
      'block': 'ब्लॉक करें',
      'share': 'साझा करें',
      'filter': 'फ़िल्टर',
      'boost': 'बूस्ट',
      'match': 'दोनों रुचि रखते हैं',
      'empty': 'अभी के लिए समाप्त।',
      'safety': 'सुरक्षा',
      'refresh': 'आज रिफ्रेश करें',
      'verifyPhone': 'कनेक्ट करने के लिए फ़ोन सत्यापित करें',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
