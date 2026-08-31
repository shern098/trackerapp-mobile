import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'models/user_model.dart';
import 'screens/map_screen.dart';
import 'screens/bus_list_screen.dart';
import 'screens/add_bus_screen.dart';
import 'screens/train_list_screen.dart';
import 'screens/add_train_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/account_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';

// Shared app-wide state, held outside any single widget so multiple
// screens (Settings, Account, the drawer, Add Bus/Train, etc.) can all
// read and react to the same values without a full state-management
// package. ValueNotifier + ValueListenableBuilder is the simplest tool
// that does this for just a couple of app-wide values.

// Who's currently signed in — null means "nobody, browsing as a guest".
// Screens that require sign-in (Add Bus, Add Train, Add Notification)
// check this before allowing their action.
final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier(null);

// Drives the current Light/Dark theme — see settings_screen.dart and
// theme_service.dart for how a value gets into this.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

// The "show/hide all buses" toggle from the drawer's sidebar switch —
// map_screen.dart checks this before rendering any live bus markers.
final ValueNotifier<bool> showBusesNotifier = ValueNotifier(true);

void main() async {
  // Required before calling any plugin (SharedPreferences, sqflite, the
  // notification plugin, etc.) before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite has no native Windows/Linux implementation — this FFI backend
  // is required on desktop. Android/iOS don't need this at all.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Restore whoever was signed in last time the app was open (if anyone),
  // via the session id AuthService persisted with SharedPreferences.
  final restoredUser = await AuthService().getCurrentUser();
  currentUserNotifier.value = restoredUser;

  // Apply the right starting theme: the signed-in user's saved
  // preference if there is one, otherwise the app-wide guest preference.
  if (restoredUser != null) {
    themeModeNotifier.value = restoredUser.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } else {
    themeModeNotifier.value = await ThemeService().loadThemeMode();
  }

  // Sets up the local notification plugin so NotificationService().showAlert()
  // works later when the geofence check in map_screen.dart fires.
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds MaterialApp whenever themeModeNotifier's value changes —
    // this is what makes picking "Dark" in Settings take effect instantly.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Transport Tracker',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.light),
          darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
          themeMode: currentThemeMode,
          initialRoute: '/',
          // Central navigation map — every screen the drawer can open is
          // registered here by name.
          routes: {
            '/': (context) => const MapScreen(),
            '/bus_list': (context) => const BusListScreen(),
            '/add_bus': (context) => const AddBusScreen(),
            '/train_list': (context) => const TrainListScreen(),
            '/add_train': (context) => const AddTrainScreen(),
            '/bus_notifications': (context) =>
                const NotificationSettingsScreen(type: 'bus'),
            '/train_notifications': (context) =>
                const NotificationSettingsScreen(type: 'train'),
            '/settings': (context) => const SettingsScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/account': (context) => const AccountScreen(),
          },
        );
      },
    );
  }
}
