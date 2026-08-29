import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import '../widgets/app_drawer.dart';
import 'dart:async';
import '../services/bus_realtime_service.dart';
import 'dart:math';
import '../models/notification_alert_model.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();

  final _busRealtimeService = BusRealtimeService();
  List<VehiclePositionInfo> _liveBuses = [];
  Timer? _pollTimer;

  bool _permissionGranted = false;
  bool _gpsEnabled = false;

  final LatLng _kualaLumpurCenter = LatLng(3.1466, 101.6958);
  String? _selectedVehicleLabel = '300';
  String? _selectedVehicleEta = '8 mins';

  final _notificationService = NotificationService();
  final _dbService = DatabaseService();
  StreamSubscription<LocationData>? _locationSub;
  final Set<int> _activeAlertIds = {}; // tracks which alerts we're currently "inside", to notify once on entry only
  static const double _geofenceRadiusMeters = 300;

  void _startGeofenceWatch() {
    _locationSub = _location.onLocationChanged.listen((locData) async {
      if (locData.latitude == null || locData.longitude == null) return;

      final busAlerts = await _dbService.getNotifications('bus');
      final trainAlerts = await _dbService.getNotifications('train');
      final allAlerts = [...busAlerts, ...trainAlerts];

      for (final alert in allAlerts) {
        final distance = _distanceMeters(
            locData.latitude!, locData.longitude!, alert.latitude, alert.longitude);
        final withinRadius = distance <= _geofenceRadiusMeters;
        final withinTime = _isWithinActiveTime(alert.startTime, alert.endTime);
        final isCurrentlyActive = _activeAlertIds.contains(alert.id);

        if (withinRadius && withinTime && !isCurrentlyActive) {
          _activeAlertIds.add(alert.id);
          await _notificationService.showAlert(
            id: alert.id,
            title: '${alert.routeRef} nearby',
            body: '${alert.name}: your ${alert.type} is close by.',
          );
        } else if ((!withinRadius || !withinTime) && isCurrentlyActive) {
          _activeAlertIds.remove(alert.id); // left the zone/time window — allow re-trigger next entry
        }
      }
    });
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  bool _isWithinActiveTime(String startTime, String endTime) {
    final now = TimeOfDay.now();
    final start = _parseTimeOfDay(startTime);
    final end = _parseTimeOfDay(endTime);
    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    return nowMin >= startMin && nowMin <= endMin;
  }

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void initState() {
    super.initState();
    checkStatus();
    _fetchLiveBuses();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchLiveBuses());
    _startGeofenceWatch();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }
  void _fetchLiveBuses() async {
    try {
      final positions = await _busRealtimeService.fetchVehiclePositions();
      debugPrint('>>> Fetched ${positions.length} live bus positions');
      if (mounted) setState(() => _liveBuses = positions);
    } catch (e) {
      debugPrint('>>> Failed to fetch live bus positions: $e');
    }
  }

  Future<bool> isPermissionGranted() async {
    return await handler.Permission.locationWhenInUse.isGranted;
  }

  Future<bool> isGpsEnabled() async {
    return await handler.Permission.location.serviceStatus.isEnabled;
  }

  void checkStatus() async {
    bool permissionGranted = await isPermissionGranted();
    bool gpsEnabled = await isGpsEnabled();
    if (!permissionGranted) {
      var status = await handler.Permission.locationWhenInUse.request();
      permissionGranted = status == handler.PermissionStatus.granted;
    }
    setState(() {
      _permissionGranted = permissionGranted;
      _gpsEnabled = gpsEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kualaLumpurCenter,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                maxZoom: 19,
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trackerapp',
              ),
              if (_permissionGranted && _gpsEnabled) CurrentLocationLayer(),
              MarkerLayer(
                markers: _liveBuses.map((bus) {
                  return Marker(
                    point: LatLng(bus.latitude, bus.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVehicleLabel = bus.routeId ?? bus.vehicleId;
                          _selectedVehicleEta = null; // no ETA field from this feed — see note below
                        });
                      },
                      child: const Icon(Icons.directions_bus, color: Colors.blue, size: 32),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white),
                ),
              ),
            ),
          ),
          if (_selectedVehicleLabel != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedVehicleLabel!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        if (_selectedVehicleEta != null)
                        Text('ETA : $_selectedVehicleEta',
                            style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
