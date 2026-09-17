import 'package:latlong2/latlong.dart';

class ShapePoint {
  final String shapeId;
  final LatLng position;
  final int sequence;

  ShapePoint({
    required this.shapeId,
    required this.position,
    required this.sequence,
  });
}