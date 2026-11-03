import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English and Tamil labels for the owner shell. Any other code stays English.
const ownerLanguageKey = 'owner_language';

final ownerLanguage = ValueNotifier<String>('en');

String ownerLanguageCode(String? raw) => raw == 'ta' ? 'ta' : 'en';

String ownerPhrase(String? language, String key) {
  final code = ownerLanguageCode(language);
  return _phrases[code]?[key] ?? _phrases['en']?[key] ?? key;
}

/// Spoken name for a shell tab. The visible word stays short. The selected tab adds a state.
String ownerTabLabel(String? language, String key, {required bool selected}) {
  final name = ownerPhrase(language, key);
  if (!selected) return name;
  return '$name, ${ownerPhrase(language, 'selected')}';
}

/// Spoken name for one notification. An unread row says so.
String ownerNoticeLabel(String? language, String title, String body, {required bool unread}) {
  final line = '$title. $body';
  if (!unread) return line;
  return '$line, ${ownerPhrase(language, 'unread')}';
}

/// The shell bar stays 68px at normal text size and grows when the system text size is larger.
double ownerBarHeight(double textScale) {
  if (textScale <= 1) return 68;
  return 68 + (textScale - 1) * 24;
}

Future<void> loadOwnerLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  ownerLanguage.value = ownerLanguageCode(prefs.getString(ownerLanguageKey));
}

Future<void> chooseOwnerLanguage(String language) async {
  final code = ownerLanguageCode(language);
  ownerLanguage.value = code;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(ownerLanguageKey, code);
}

const _phrases = {
  'en': {
    'venues': 'Venues',
    'bookings': 'Bookings',
    'earnings': 'Earnings',
    'chat': 'Chat',
    'profile': 'Profile',
    'notifications': 'Notifications',
    'no_notifications': 'No notifications',
    'caught_up': 'You\'re all caught up',
    'language': 'Language',
    'english': 'English',
    'tamil': 'Tamil',
    'selected': 'selected',
    'unread': 'unread',
  },
  'ta': {
    'venues': 'அரங்கங்கள்',
    'bookings': 'முன்பதிவுகள்',
    'earnings': 'வருமானம்',
    'chat': 'அரட்டை',
    'profile': 'சுயவிவரம்',
    'notifications': 'அறிவிப்புகள்',
    'no_notifications': 'அறிவிப்புகள் இல்லை',
    'caught_up': 'எல்லாம் பார்த்துவிட்டீர்கள்',
    'language': 'மொழி',
    'english': 'English',
    'tamil': 'தமிழ்',
    'selected': 'தேர்ந்தெடுக்கப்பட்டது',
    'unread': 'படிக்கவில்லை',
  },
};
