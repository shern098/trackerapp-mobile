import 'package:flutter/material.dart';
import '../main.dart' show themeModeNotifier, currentUserNotifier;
import '../services/theme_service.dart';
import '../services/auth_service.dart';


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
    themeModeNotifier.value = mode;
    setState(() => _isSaving = true);

    final user = currentUserNotifier.value;
    try {
      if (user != null) {
        await _authService.updateThemeMode(
            user, mode == ThemeMode.dark ? 'dark' : 'light');
      } else {
        await _themeService.saveThemeMode(mode);
      }
    } catch (e) {
      themeModeNotifier.value = previousMode;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save theme')),
        );
        debugPrint('>>>theme update fail : $e');
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