import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import '../models/notification_alert_model.dart';
import '../models/bus_model.dart';
import '../models/train_model.dart';
import '../services/database_service.dart';

class AddNotificationScreen extends StatefulWidget {
  final String type; // 'bus' or 'train'

  const AddNotificationScreen({super.key, required this.type});

  @override
  State<AddNotificationScreen> createState() => _AddNotificationScreenState();
}

class _AddNotificationScreenState extends State<AddNotificationScreen> {
  final _nameController = TextEditingController();
  final _dbService = DatabaseService();
  final _location = Location();

  String _locationLabel = '';
  String? _selectedRoute;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  String _sound = 'Default';
  String _vibrate = 'Default';

  double? _latitude;
  double? _longitude;

  // Same permission-check pattern as Practical 13 / MapScreen
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
      _latitude = locationData.latitude;   // NEW
      _longitude = locationData.longitude; // NEW
    });
  }

  Future<void> _pickRoute() async {
    final routeRef = widget.type == 'bus'
        ? await _pickFromList<BusModel>(
            future: _dbService.getBuses(), labelOf: (b) => b.busNumber)
        : await _pickFromList<TrainModel>(
            future: _dbService.getTrains(), labelOf: (t) => t.lineName);
    if (routeRef != null) setState(() => _selectedRoute = routeRef);
  }

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

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _saveNotification() async {
    if (_nameController.text.trim().isEmpty || _selectedRoute == null || _latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in a name, select a route, and set a location.')));
      return;
    }

    final alert = NotificationAlertModel(
      id: 0,
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

    await _dbService.insertNotification(alert);
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Sound : $_sound'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: replace with a real sound picker (dropdown/menu)
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
