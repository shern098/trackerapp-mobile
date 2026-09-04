import 'dart:async';
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

  Timer? _pollTimer;
  StreamSubscription<LocationData>? _locationSub;

  bool _permissionGranted = false;
  bool _gpsEnabled = false;

  final LatLng _fallbackCenter = LatLng(3.1466, 101.6958); // Kuala Lumpur
  String? _selectedVehicleLabel;

  Future<bool> isPermissionGranted() async {
    return await handler.Permission.locationWhenInUse.isGranted;
  }
  Future<bool> isGpsEnabled() async {
    return await handler.Permission.location.serviceStatus.isEnabled;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
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

  void _showLocationFallbackMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to get your location. Showing default view.')),
    );
  }


  @override
  void initState() {
    super.initState();
    checkStatus();
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

