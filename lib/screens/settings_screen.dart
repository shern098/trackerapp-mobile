import 'package:flutter/material.dart';
import '../main.dart' show themeModeNotifier, currentUserNotifier;
import '../services/theme_service.dart';
import '../services/auth_service.dart';

/// Lets the user switch between light and dark theme via a dropdown.
/// If signed in, the choice is saved to that account's row in the Users
/// table (via AuthService), so it's remembered per-account. If not
/// signed in, it falls back to a single app-wide guest preference saved
/// with SharedPreferences (ThemeService — same pattern as Practical 7),
/// so switching themes still works before anyone logs in.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _themeService = ThemeService();
  final _authService = AuthService();
  ThemeMode _selectedTheme = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    // Pre-select whatever theme is currently active, so the dropdown
    // reflects reality instead of always resetting to "Light".
    _selectedTheme = themeModeNotifier.value;
  }

  void _onThemeChanged(ThemeMode? mode) async {
    if (mode == null) return;
    setState(() => _selectedTheme = mode);
    themeModeNotifier.value = mode; // updates the running app immediately

    final user = currentUserNotifier.value;
    if (user != null) {
      // Signed in — persist to this account specifically.
      await _authService.updateThemeMode(user, mode == ThemeMode.dark ? 'dark' : 'light');
    } else {
      // Not signed in — fall back to a single app-wide guest preference.
      await _themeService.saveThemeMode(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = currentUserNotifier.value == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButton<ThemeMode>(
              value: _selectedTheme,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: _onThemeChanged,
            ),
            if (isGuest) ...[
              const SizedBox(height: 8),
              const Text(
                'Sign in to make this preference part of your account — right now it\'s saved on this device only.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
