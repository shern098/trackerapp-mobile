import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import '../models/notification_alert_model.dart';
import '../models/bus_model.dart';
import '../models/train_model.dart';
import '../services/database_service.dart';
import '../main.dart' show currentUserNotifier;

/// Form for creating one geofence alert: a name, a real GPS location
/// (captured via the device's own position — same permission pattern as
/// Practical 13), a saved bus/train to watch, an active time window, and
/// sound/vibrate preferences. Saving here is what actually makes
/// map_screen.dart's geofence check able to notify the user later.
class AddNotificationScreen extends StatefulWidget {
  final String type; // 'bus' or 'train' — determines which saved routes are offered

  const AddNotificationScreen({super.key, required this.type});

  @override
  State<AddNotificationScreen> createState() => _AddNotificationScreenState();
}

class _AddNotificationScreenState extends State<AddNotificationScreen> {
  final _nameController = TextEditingController();
  final _dbService = DatabaseService();
  final _location = Location();

  String _locationLabel = '';
  double? _latitude; // actual GPS coordinate — required before saving
  double? _longitude;
  String? _selectedRoute;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  String _sound = 'Default';
  String _vibrate = 'Default';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Captures the device's real current GPS position — same permission
  // request pattern as Practical 13 (Location Tracking) — and stores
  // both a display label and the actual lat/lng needed for the geofence
  // math in map_screen.dart.
  Future<void> _useCurrentLocation() async {
    bool granted = await handler.Permission.locationWhenInUse.isGranted;
    if (!granted) {
      final status = await handler.Permission.locationWhenInUse.request();
      granted = status == handler.PermissionStatus.granted;
    }
    if (!granted) return;

    final locationData = await _location.getLocation();
    setState(() {
      _locationLabel = 'Current Location';
      _nameController.text = 'Current Location';
      _latitude = locationData.latitude;
      _longitude = locationData.longitude;
    });
  }

  // Opens a simple picker dialog listing the signed-in user's already-
  // saved buses or trains (depending on widget.type), so the alert can
  // reference one of them by name.
  Future<void> _pickRoute() async {
    final userId = currentUserNotifier.value?.id;
    if (userId == null) return; // shouldn't happen — this screen requires sign-in to reach

    final routeRef = widget.type == 'bus'
        ? await _pickFromList<BusModel>(
            future: _dbService.getBuses(userId), labelOf: (b) => b.busNumber)
        : await _pickFromList<TrainModel>(
            future: _dbService.getTrains(userId), labelOf: (t) => t.lineName);
    if (routeRef != null) setState(() => _selectedRoute = routeRef);
  }

  // Generic helper so the same dialog code works for both BusModel and
  // TrainModel lists without duplicating the dialog-building logic twice.
  Future<String?> _pickFromList<T>({
    required Future<List<T>> future,
    required String Function(T) labelOf,
  }) async {
    final items = await future;
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select a route'),
        children: items
            .map((item) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, labelOf(item)),
                  child: Text(labelOf(item)),
                ))
            .toList(),
      ),
    );
  }

  // Opens two time pickers back-to-back for the alert's active window.
  Future<void> _pickTimeRange() async {
    final start = await showTimePicker(context: context, initialTime: _startTime);
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: _endTime);
    if (end == null) return;
    setState(() {
      _startTime = start;
      _endTime = end;
    });
  }

  // Formats a TimeOfDay as "HH:MM" — the string format saved to the
  // database and later parsed back by map_screen.dart's geofence check.
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Validates the form, builds a NotificationAlertModel, and saves it —
  // requires a name, a selected route, AND a captured location (can't
  // geofence-check an alert with no coordinates) — plus a signed-in user
  // to tag the alert to.
  void _saveNotification() async {
    if (_nameController.text.trim().isEmpty || _selectedRoute == null || _latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in a name, select a route, and set a location.')));
      return;
    }

    final userId = currentUserNotifier.value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in to save an alert.')));
      return;
    }

    final alert = NotificationAlertModel(
      id: 0, // ignored on insert — SQLite auto-assigns the real id
      name: _nameController.text.trim(),
      location: _locationLabel,
      latitude: _latitude!,
      longitude: _longitude!,
      type: widget.type,
      routeRef: _selectedRoute!,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
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
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_locationLabel.isEmpty ? 'Current Location' : _locationLabel),
          ),
          const SizedBox(height: 20),
          const Text('Relevant Routes :', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Text(_selectedRoute ?? 'None selected', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(onPressed: _pickRoute, child: const Text('Add route')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Active Time :', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Text('[${_formatTime(_startTime)}]  to  [${_formatTime(_endTime)}]',
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(onPressed: _pickTimeRange, child: const Text('Add Time')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Sound/Vibrate are simple toggle-stubs (tap cycles between two
          // hardcoded values) rather than a real dropdown — flagged as a
          // known simplification in the README.
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
