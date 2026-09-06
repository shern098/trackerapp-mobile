import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackerapp/screens/add_train_screen.dart';
import 'package:trackerapp/screens/notification_settings_screen.dart';
import 'package:trackerapp/screens/train_list_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'package:trackerapp/services/notification_service.dart';
import 'models/user_model.dart';
import 'screens/map_screen.dart';
import 'screens/bus_list_screen.dart';
import 'screens/add_bus_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/account_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';

final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier(null);
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final restoredUser = await AuthService().getCurrentUser();
  currentUserNotifier.value = restoredUser;

  if (restoredUser != null) {
    themeModeNotifier.value = restoredUser.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } else {
    themeModeNotifier.value = await ThemeService().loadThemeMode();
  }
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, currentThemeMode, _) {
          return MaterialApp(
            title: 'TrackerApp',

            theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.light),
            darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
            themeMode: currentThemeMode,
            navigatorObservers: [routeObserver],
            initialRoute: '/',
            routes: {
              '/': (context) => const MapScreen(),
              '/bus_list': (context) => const BusListScreen(),
              '/add_bus': (context) => const AddBusScreen(),
              '/train_list': (context) => const TrainListScreen(),
              '/add_train': (context) => const AddTrainScreen(),
              '/notifications': (context) => const NotificationSettingsScreen(),

              '/settings': (context) => const SettingsScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/account': (context) => const AccountScreen(),
            },
          );
        });
  }
}