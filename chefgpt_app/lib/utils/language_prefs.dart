import 'package:shared_preferences/shared_preferences.dart';

const String _langKey = 'chefgpt_lang';

/// Returns the stored language code: 'en' or 'ms'. Defaults to 'en'.
Future<String> getLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_langKey) ?? 'en';
}

/// Persists the chosen language code ('en' or 'ms').
Future<void> setLanguage(String lang) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_langKey, lang);
}
