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
  bool _isSaving = false;

  Future<void> _onThemeChanged(ThemeMode? mode) async {
    if (mode == null || _isSaving) return;

    final previousMode = themeModeNotifier.value;
    themeModeNotifier.value = mode; // updates the running app immediately
    setState(() => _isSaving = true);

    final user = currentUserNotifier.value;
    try {
      if (user != null) {
        // Signed in — persist to this account specifically.
        await _authService.updateThemeMode(
            user, mode == ThemeMode.dark ? 'dark' : 'light');
      } else {
        // Not signed in — fall back to a single app-wide guest preference.
        await _themeService.saveThemeMode(mode);
      }
    } catch (e) {
      // Saving failed — revert the visible theme so the UI doesn't claim
      // a preference that wasn't actually persisted, and let the user know.
      themeModeNotifier.value = previousMode;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save theme: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentTheme, _) {
        return ValueListenableBuilder(
          valueListenable: currentUserNotifier,
          builder: (context, user, _) {
            final isGuest = user == null;

            return Scaffold(
              appBar: AppBar(title: const Text('Settings')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Theme',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        if (_isSaving) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<ThemeMode>(
                      value: currentTheme,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(
                            value: ThemeMode.dark, child: Text('Dark')),
                      ],
                      onChanged: _isSaving ? null : _onThemeChanged,
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
          },
        );
      },
    );
  }
}