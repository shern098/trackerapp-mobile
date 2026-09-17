import 'package:latlong2/latlong.dart';

enum VehicleType {
  bus,
  train,
}

class Vehicle {
  final String id;
  final String routeId;
  final String tripId;
  final VehicleType type;
  final LatLng position;
  final double speed;
  final double bearing;
  final int timestamp;

  Vehicle({
    required this.id,
    required this.routeId,
    required this.tripId,
    required this.type,
    required this.position,
    required this.speed,
    required this.bearing,
    required this.timestamp,
  });
}