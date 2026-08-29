import 'package:flutter/material.dart';
import '../models/notification_alert_model.dart';
import '../services/database_service.dart';
import 'add_notification_screen.dart';

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
  late Future<List<NotificationAlertModel>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _alertsFuture = dbService.getNotifications(widget.type);
    });
  }

  void _deleteAlert(int id) async {
    await dbService.deleteNotification(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'bus' ? 'Bus Notification Setting' : 'Train Notification Setting';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<NotificationAlertModel>>(
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
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddNotificationScreen(type: widget.type)),
          );
          _refresh();
        },
      ),
    );
  }
}
