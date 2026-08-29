import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/bus_list_screen.dart';
import 'screens/add_bus_screen.dart';
import 'screens/train_list_screen.dart';
import 'screens/add_train_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/account_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const TransportTrackerApp());
}

class TransportTrackerApp extends StatelessWidget {
  const TransportTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transport Tracker',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
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
