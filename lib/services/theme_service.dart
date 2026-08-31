import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen theme (light/dark) to local storage.
///
/// This follows the same pattern as Practical 7 (Shared Preferences):
/// get an instance of SharedPreferences, then read/write simple key-value
/// pairs with getString()/setString(). The only difference from the
/// practical's name/email example is that we're storing a ThemeMode
/// instead of free text, so it's converted to/from a plain string.
class ThemeService {
  static const _themeKey = 'themeMode';

  // Same style as Practical 7's _loadProfile() — read a saved value back
  // out of SharedPreferences, with a sensible default if nothing was
  // saved yet (first time the app runs).
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey) ?? 'light';
    return saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  // Same style as Practical 7's _updateProfile() — write a value into
  // SharedPreferences so it persists across app restarts.
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
