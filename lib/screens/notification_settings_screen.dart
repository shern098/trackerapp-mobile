import 'package:flutter/material.dart';
import '../models/notification_alert_model.dart';
import '../services/database_service.dart';
import '../main.dart' show currentUserNotifier;
import 'add_notification_screen.dart';
import 'login_screen.dart';

/// One screen reused for BOTH "Bus Notification Setting" and "Train
/// Notification Setting" — which list it shows depends on the `type`
/// passed in (see main.dart's routes). Lists the signed-in user's saved
/// alerts of that type; the actual geofence-check-and-notify logic lives
/// in map_screen.dart, not here — this screen only manages the saved list.
class NotificationSettingsScreen extends StatefulWidget {
  final String type; // 'bus' or 'train'

  const NotificationSettingsScreen({super.key, required this.type});

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
      _alertsFuture = userId != null ? dbService.getNotifications(userId, widget.type) : null;
    });
  }

  void _deleteAlert(int id) async {
    await dbService.deleteNotification(id);
    _refresh();
  }

  // Alerts reference a saved bus/train, so creating one requires being
  // signed in — same gating pattern as Bus List / Train List's Add button.
  void _onAddPressed() async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refresh();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddNotificationScreen(type: widget.type)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'bus' ? 'Bus Notification Setting' : 'Train Notification Setting';
    final isGuest = currentUserNotifier.value == null;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                        title: Text(alert.name),
                        subtitle: Text('${alert.routeRef} • ${alert.startTime}–${alert.endTime}'),
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
