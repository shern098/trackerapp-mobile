import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import '../widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();

  bool _permissionGranted = false;
  bool _gpsEnabled = false;

  final LatLng _kualaLumpurCenter = LatLng(3.1466, 101.6958);
  String? _selectedVehicleLabel = '300';
  String? _selectedVehicleEta = '8 mins';

  @override
  void initState() {
    super.initState();
    checkStatus();
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
                userAgentPackageName: 'com.example.transport_tracker',
              ),
              if (_permissionGranted && _gpsEnabled) CurrentLocationLayer(),
              MarkerLayer(
                markers: [
                  // TODO: Replace this single hardcoded marker with one Marker
                  // per bus/train the user has saved (from DatabaseService),
                  // positioned using live GTFS-realtime vehicle coordinates.
                  Marker(
                    point: _kualaLumpurCenter,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVehicleLabel = '300';
                          _selectedVehicleEta = '8 mins';
                        });
                      },
                      child: const Icon(Icons.directions_bus,
                          color: Colors.blue, size: 32),
                    ),
                  ),
                ],
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
