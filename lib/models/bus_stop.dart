import 'package:latlong2/latlong.dart';

class BusStop {
  final String id;
  final String name;
  final String description;
  final LatLng position;

  BusStop({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
  });
}