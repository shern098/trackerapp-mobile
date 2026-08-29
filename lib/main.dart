import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/bus_list_screen.dart';
import 'screens/add_bus_screen.dart';
import 'screens/train_list_screen.dart';
import 'screens/add_train_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/account_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite has no native Windows/Linux implementation — this FFI backend
  // is required on desktop. Android/iOS don't need this at all.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transport Tracker',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.lightBlueAccent),
      initialRoute: '/',
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
        '/account': (context) => const AccountScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
