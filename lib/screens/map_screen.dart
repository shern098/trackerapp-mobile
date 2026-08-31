import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import '../widgets/app_drawer.dart';
import '../services/bus_realtime_service.dart';
import '../services/route_lookup_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../main.dart' show showBusesNotifier, currentUserNotifier;

/// The app's home screen — an OpenStreetMap view (Practical 12) showing
/// live bus positions (via GTFS-Realtime), with the user's own live
/// location shown as a blue dot (Practical 13). Also runs a continuous
/// geofence check in the background: whenever the device enters a saved
/// notification alert's radius during its active time window, it fires a
/// real OS notification.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();

  final _busRealtimeService = BusRealtimeService();
  final _routeLookupService = RouteLookupService();
  final _notificationService = NotificationService();
  final _dbService = DatabaseService();

  List<VehiclePositionInfo> _liveBuses = []; // refreshed every 30s by _fetchLiveBuses()
  Timer? _pollTimer;
  StreamSubscription<LocationData>? _locationSub;

  // Tracks which notification alerts are currently "active" (i.e. we're
  // inside their radius + time window right now) so we only fire the
  // notification once on entry, not repeatedly every location update
  // while standing still inside the zone.
  final Set<int> _activeAlertIds = {};
  static const double _geofenceRadiusMeters = 300;

  bool _permissionGranted = false;
  bool _gpsEnabled = false;

  final LatLng _kualaLumpurCenter = LatLng(3.1466, 101.6958);
  String? _selectedVehicleLabel; // shown in the bottom sheet when a bus marker is tapped
  String? _selectedVehicleEta;

  @override
  void initState() {
    super.initState();
    checkStatus(); // location permission check, same pattern as Practical 13
    _fetchLiveBuses(); // fetch once immediately on load
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchLiveBuses());
    _startGeofenceWatch();
    // Rebuilds the map whenever the drawer's "Show All Buses" switch
    // changes, so markers appear/disappear immediately.
    showBusesNotifier.addListener(_onShowBusesChanged);
  }

  void _onShowBusesChanged() => setState(() {});

  // Calls the GTFS-Realtime feed and refreshes the map's bus markers.
  // Returning 0 buses is expected/normal outside RapidKL's operating
  // hours (roughly 6am-midnight) — not a bug.
  void _fetchLiveBuses() async {
    try {
      final positions = await _busRealtimeService.fetchVehiclePositions();
      debugPrint('>>> Fetched ${positions.length} live bus positions');
      if (mounted) setState(() => _liveBuses = positions);
    } catch (e) {
      debugPrint('>>> Failed to fetch live bus positions: $e');
    }
  }

  // Listens to the device's live location stream and checks it against
  // every saved notification alert on every update. This is the actual
  // "notify me when I'm near my bus stop" feature. Only runs alerts for
  // whoever is currently signed in — guests have no saved alerts to check.
  void _startGeofenceWatch() {
    _locationSub = _location.onLocationChanged.listen((locData) async {
      if (locData.latitude == null || locData.longitude == null) return;

      final userId = currentUserNotifier.value?.id;
      if (userId == null) return; // not signed in — nothing to check

      final busAlerts = await _dbService.getNotifications(userId, 'bus');
      final trainAlerts = await _dbService.getNotifications(userId, 'train');
      final allAlerts = [...busAlerts, ...trainAlerts];

      for (final alert in allAlerts) {
        final distance = _distanceMeters(
            locData.latitude!, locData.longitude!, alert.latitude, alert.longitude);
        final withinRadius = distance <= _geofenceRadiusMeters;
        final withinTime = _isWithinActiveTime(alert.startTime, alert.endTime);
        final isCurrentlyActive = _activeAlertIds.contains(alert.id);

        if (withinRadius && withinTime && !isCurrentlyActive) {
          // Just entered the zone during the active window — fire once.
          _activeAlertIds.add(alert.id);
          await _notificationService.showAlert(
            id: alert.id,
            title: '${alert.routeRef} nearby',
            body: '${alert.name}: your ${alert.type} is close by.',
          );
        } else if ((!withinRadius || !withinTime) && isCurrentlyActive) {
          // Left the zone or time window — reset so it can fire again
          // next time we re-enter.
          _activeAlertIds.remove(alert.id);
        }
      }
    });
  }

  // Haversine formula — standard way to calculate straight-line distance
  // in meters between two lat/lng points on Earth's surface.
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  // Compares the current time-of-day against an alert's saved start/end
  // time strings (e.g. "09:00" to "11:00").
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
  void dispose() {
    // Always cancel timers/streams/listeners in dispose() — same
    // reasoning as Practical 7's TextEditingController.dispose() calls:
    // without this, these would keep running (and leaking memory) after
    // the screen closes.
    _pollTimer?.cancel();
    _locationSub?.cancel();
    showBusesNotifier.removeListener(_onShowBusesChanged);
    super.dispose();
  }

  // ---- Location permission handling (same pattern as Practical 13) ----

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
          // The actual OpenStreetMap map widget (Practical 12)
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
              // The user's own live GPS position, shown as a blue dot —
              // only drawn once permission + GPS are actually available.
              if (_permissionGranted && _gpsEnabled) CurrentLocationLayer(),
              // One marker per currently-live bus from _liveBuses — but
              // only if the drawer's "Show All Buses" switch is on.
              MarkerLayer(
                markers: showBusesNotifier.value
                    ? _liveBuses.map((bus) {
                  return Marker(
                    point: LatLng(bus.latitude, bus.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () async {
                        // Show something immediately so the tap doesn't
                        // feel unresponsive while we resolve the real
                        // bus number in the background.
                        setState(() {
                          _selectedVehicleLabel = 'Looking up...';
                          _selectedVehicleEta = null;
                        });

                        // Translate the raw route_id into a human-readable
                        // bus number (e.g. "300") if possible.
                        String displayLabel = bus.routeId ?? bus.vehicleId;
                        if (bus.routeId != null) {
                          final shortName = await _routeLookupService
                              .shortNameForRouteId('rapid-bus-kl', bus.routeId!);
                          if (shortName != null) displayLabel = shortName;
                        }

                        if (mounted) {
                          setState(() {
                            _selectedVehicleLabel = displayLabel;
                            _selectedVehicleEta = null;
                          });
                        }
                      },
                      child: const Icon(Icons.directions_bus,
                          color: Colors.blue, size: 32),
                    ),
                  );
                }).toList()
                    : [], // switch is off — render no bus markers at all
              ),
            ],
          ),

          // Hamburger menu button — opens the AppDrawer
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

          // Bottom sheet showing whichever bus marker was last tapped
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
                        // Only shown if we actually have an ETA value —
                        // avoids literally printing "ETA : null".
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
