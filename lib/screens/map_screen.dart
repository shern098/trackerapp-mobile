import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import '../main.dart' show currentUserNotifier, routeObserver;
import '../widgets/app_drawer.dart';
import '../services/bus_realtime_service.dart';
import '../services/route_lookup_service.dart';
import '../services/transit_api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/bus_model.dart';
import '../models/train_model.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with RouteAware {

  final MapController _mapController = MapController();
  final Location _location = Location();

  final _busRealtimeService = BusRealtimeService();
  final _routeLookupService = RouteLookupService();
  final _transitApiService = TransitApiService();
  final _notificationService = NotificationService();
  final _dbService = DatabaseService();

  List<VehiclePositionInfo> _liveBuses = [];
  Map<String, String> _routeIdToShortName = {};
  List<BusModel> _savedBuses = [];
  final Map<String, List<LatLng>> _routeShapeCache = {};
  List<TrainModel> _savedTrains = [];
  final Map<String, List<LatLng>> _trainRouteShapeCache = {};

  Timer? _pollTimer;
  StreamSubscription<LocationData>? _locationSub;

  final Set<int> _activeAlertIds = {};
  static const double _geofenceRadiusMeters = 300;

  bool _permissionGranted = false;
  bool _gpsEnabled = false;

  final LatLng _fallbackCenter = LatLng(3.1466, 101.6958); // Kuala Lumpur
  String? _selectedVehicleLabel;
  String? _selectedVehicleEta;

  // List<VehiclePositionInfo> get _visibleBuses => _liveBuses; //!!!show all in case dov data unavailable AGAIN ?!!!@#!@#!#!!!

  // !!!show only in my list !!1
  List<VehiclePositionInfo> get _visibleBuses {
    final visibleNumbers = _savedBuses
        .where((b) => b.iconVisible == 1)
        .map((b) => b.busNumber)
        .toSet();

    if (visibleNumbers.isEmpty) return [];

    return _liveBuses.where((bus) {
      final key = bus.routeId != null ? '${bus.category}_${bus.routeId}' : null;
      final shortName = key != null ? _routeIdToShortName[key] : null;
      return shortName != null && visibleNumbers.contains(shortName);
    }).toList();
  }

  List<Polyline> get _visiblePolylines {
    final busPolylines = _savedBuses
        .where((b) =>
    b.routeVisible == 1 &&
        (_routeShapeCache[b.busNumber]?.isNotEmpty ?? false))
        .map((b) => Polyline(
      points: _routeShapeCache[b.busNumber]!,
      strokeWidth: 4,
      color: Colors.blue,
    ));

    final trainPolylines = _savedTrains
        .where((t) =>
    t.visible == 1 &&
        (_trainRouteShapeCache[t.lineName]?.isNotEmpty ?? false))
        .map((t) => Polyline(
      points: _trainRouteShapeCache[t.lineName]!,
      strokeWidth: 4,
      color: Colors.orange,
    ));

    return [...busPolylines, ...trainPolylines];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pollTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped off, and the current route (Map) shows up.
    debugPrint('>>> Returning to MapScreen: Refreshing data...');
    _refreshAll();
  }


  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  void _showLocationFallbackMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to get your location. Showing default view.')),
    );
  }

  void _startGeofenceWatch() {
    _locationSub = _location.onLocationChanged.listen((locData) async {
      if (locData.latitude == null || locData.longitude == null) return;

      final userId = currentUserNotifier.value?.id;
      if (userId == null) return; // not signed in — nothing to check

      final alerts = await _dbService.getNotifications(userId);

      for (final alert in alerts) {
        VehiclePositionInfo? matchingBus;
        for (final bus in _liveBuses) {
          final shortName = bus.routeId != null ? _routeIdToShortName[bus.routeId] : null;
          if (shortName == alert.routeRef) {
            matchingBus = bus;
            break;
          }
        }

        if (matchingBus == null) {
          _activeAlertIds.remove(alert.id);
          continue;
        }

        final distance = _distanceMeters(
            locData.latitude!, locData.longitude!, matchingBus.latitude, matchingBus.longitude);
        final withinRadius = distance <= _geofenceRadiusMeters;
        final isCurrentlyActive = _activeAlertIds.contains(alert.id);

        if (withinRadius && !isCurrentlyActive) {
          _activeAlertIds.add(alert.id);
          await _notificationService.showAlert(
            id: alert.id,
            title: 'Bus ${alert.routeRef} nearby',
            body: 'Bus ${alert.routeRef} is within ${_geofenceRadiusMeters.round()}m of you.',
          );
        } else if (!withinRadius && isCurrentlyActive) {
          _activeAlertIds.remove(alert.id);
        }
      }
    });
  }

  Future<void> _refreshSavedBuses() async {
    final userId = currentUserNotifier.value?.id;
    final buses = userId != null ? await _dbService.getBuses(userId) : <BusModel>[];
    if (mounted) setState(() => _savedBuses = buses);
  }

  Future<void> _refreshRouteShapes() async {
    for (final bus in _savedBuses) {
      if (bus.routeVisible == 1 && !_routeShapeCache.containsKey(bus.busNumber)) {
        final shape = await _transitApiService.fetchBusRouteShape(bus.busNumber);
        if (mounted) setState(() => _routeShapeCache[bus.busNumber] = shape);
      }
    }
  }

  Future<void> _refreshSavedTrains() async {
    final userId = currentUserNotifier.value?.id;
    final trains = userId != null ? await _dbService.getTrains(userId) : <TrainModel>[];
    if (mounted) setState(() => _savedTrains = trains);
  }

  Future<void> _refreshTrainRouteShapes() async {
    for (final train in _savedTrains) {
      if (train.visible == 1 && !_trainRouteShapeCache.containsKey(train.lineName)) {
        final shape = await _transitApiService.fetchTrainRouteShape(train.lineName);
        if (mounted) setState(() => _trainRouteShapeCache[train.lineName] = shape);
      }
    }
  }

  Future<void> _fetchLiveBuses() async {
    final categories = [
      'rapid-bus-kl',
      'rapid-bus-penang',
      'rapid-bus-kuantan',
      'rapid-bus-mrtfeeder',
      'rapid-rail-kl',
    ];

    try {
      final results = await Future.wait(
        categories.map((cat) async {
          final positions = await _busRealtimeService
          .fetchVehiclePositions(cat)
          .catchError((e) => <VehiclePositionInfo>[]);

          debugPrint('>>> Fetched ${positions.length} live positions from $cat');
          return positions;
        }),
      );

      final allPositions = results.expand((x) => x).toList();

      final resolved = <String, String>{};
      for (final bus in allPositions) {
      if (bus.routeId == null) continue;

      final key = '${bus.category}_${bus.routeId}';
      if (resolved.containsKey(key)) continue;

      final shortName = await _routeLookupService.shortNameForRouteId(bus.category, bus.routeId!);
      if (shortName != null) resolved[key] = shortName;
      }

      if (mounted) {
      setState(() {
      _liveBuses = allPositions;
      _routeIdToShortName = resolved;
      });
      }
      } catch (e) {
      debugPrint('>>> Failed to fetch live bus positions: $e');
      }
  }

  void _refreshAll() async {
    await _fetchLiveBuses();
    await _refreshSavedBuses();
    await _refreshRouteShapes();
    await _refreshSavedTrains();
    await _refreshTrainRouteShapes();
  }

  @override
  void initState() {
    super.initState();
    checkStatus();
    _refreshAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshAll());
    _startGeofenceWatch();
  }

  Future<bool> isPermissionGranted() async {
    return await handler.Permission.locationWhenInUse.isGranted;
  }

  Future<bool> isGpsEnabled() async {
    return await handler.Permission.location.serviceStatus.isEnabled;
  }

  void checkStatus() async{
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

    if (permissionGranted && gpsEnabled) {

      try {
        final locationData = await _location.getLocation();
        if (locationData.latitude != null && locationData.longitude != null) {
          _mapController.move(
            LatLng(locationData.latitude!, locationData.longitude!),
            15,
          );
        } else {
          throw Exception("Null coords L + ratioed");
        }
      } catch (e) {
        debugPrint('>>> Could not get user location to center map: $e');
        _showLocationFallbackMessage();
      }

    } else {
      _showLocationFallbackMessage();
    }
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
              initialCenter: _fallbackCenter,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                maxZoom: 19,
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trackerapp',
              ),
              PolylineLayer(polylines: _visiblePolylines),
              MarkerLayer(
                markers: _visibleBuses.map((bus) => Marker(
                  point: LatLng(bus.latitude, bus.longitude),
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.directions_bus, color: Colors.blue),
                )).toList(),
              ),
              if (_permissionGranted && _gpsEnabled) CurrentLocationLayer(),
            ],
          ),

          Positioned(
            top: 16,
            left: 16,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: (){
                  debugPrint("hamburger menu tapped");
                  Scaffold.of(context).openDrawer();
                },
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

        ],
      ),
    );
  }

}

