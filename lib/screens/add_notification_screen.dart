import 'package:flutter/material.dart';
import '../models/notification_alert_model.dart';
import '../models/bus_model.dart';
import '../services/database_service.dart';
import '../main.dart' show currentUserNotifier;

class AddNotificationScreen extends StatefulWidget {
  const AddNotificationScreen({super.key});

  @override
  State<AddNotificationScreen> createState() => _AddNotificationScreenState();
}

class _AddNotificationScreenState extends State<AddNotificationScreen> {
  final _dbService = DatabaseService();

  String? _selectedRoute;
  String _sound = 'Default';
  String _vibrate = 'Default';

  Future<void> _pickRoute() async {
    final userId = currentUserNotifier.value?.id;
    if (userId == null) return;

    final buses = await _dbService.getBuses(userId);
    if (!mounted) return;

    final routeRef = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select a bus'),
        children: buses
            .map((b) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, b.busNumber),
                  child: Text('Bus ${b.busNumber}'),
                ))
            .toList(),
      ),
    );
    if (routeRef != null) setState(() => _selectedRoute = routeRef);
  }

  void _saveNotification() async {
    if (_selectedRoute == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a bus.')));
      return;
    }

    final userId = currentUserNotifier.value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in to save an alert.')));
      return;
    }

    final alert = NotificationAlertModel(
      id: 0,
      routeRef: _selectedRoute!,
      sound: _sound,
      vibrate: _vibrate,
    );

    await _dbService.insertNotification(userId, alert);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Notification Alert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Bus :', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Text(
                  _selectedRoute != null ? 'Bus $_selectedRoute' : 'None selected',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _pickRoute, child: const Text('Choose bus')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Sound : $_sound'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() => _sound = _sound == 'Default' ? 'Chime' : 'Default');
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Vibrate : $_vibrate'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() => _vibrate = _vibrate == 'Default' ? 'Off' : 'Default');
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, padding: const EdgeInsets.all(16)),
              onPressed: _saveNotification,
              child: const Text('Add Notification', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
