import 'package:flutter/material.dart';
import '../models/notification_alert_model.dart';
import '../services/database_service.dart';
import '../main.dart' show currentUserNotifier;
import 'add_notification_screen.dart';
import 'login_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final dbService = DatabaseService();
  Future<List<NotificationAlertModel>>? _alertsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final userId = currentUserNotifier.value?.id;
    setState(() {
      _alertsFuture = userId != null ? dbService.getNotifications(userId) : null;
    });
  }

  void _deleteAlert(int id) async {
    await dbService.deleteNotification(id);
    _refresh();
  }

  void _onAddPressed() async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refresh();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddNotificationScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = currentUserNotifier.value == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: isGuest
          ? const Center(
              child: Text('Sign in to see and add notification alerts.',
                  textAlign: TextAlign.center),
            )
          : FutureBuilder<List<NotificationAlertModel>>(
              future: _alertsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No notification alerts set up yet.'));
                }
                final alerts = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black26)),
                      child: ListTile(
                        title: Text('Bus ${alert.routeRef}'),
                        subtitle: const Text('Notifies when this bus is nearby'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteAlert(alert.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        child: const Icon(Icons.add),
      ),
    );
  }
}
