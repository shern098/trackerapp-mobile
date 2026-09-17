import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route.dart';

class RouteLayer extends StatelessWidget {
  final GtfsRoute route;

  // Each list represents one direction.
  final List<List<LatLng>> points;

  final int colorIndex;

  const RouteLayer({
    super.key,
    required this.route,
    required this.points,
    this.colorIndex = 0,
  });

  static const List<Color> routeColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    const int arrowSpacing = 15;

    final List<Polyline> polylines = [];
    final List<Marker> arrows = [];

    final Color routeColor =
    routeColors[colorIndex % routeColors.length];

    // Process every direction.
    for (final directionPoints in points) {
      if (directionPoints.length < 2) {
        continue;
      }

      // Draw the route line.
      polylines.add(
        Polyline(
          points: directionPoints,
          strokeWidth: 6,
          color: routeColor,
        ),
      );

      // Add arrows along this direction.
      for (
      int i = 0;
      i < directionPoints.length - 1;
      i += arrowSpacing
      ) {
        final start = directionPoints[i];

        final end = directionPoints[i + 1];

        final bearing = _calculateBearing(
          start,
          end,
        );

        arrows.add(
          Marker(
            point: start,
            width: 24,
            height: 24,
            child: Transform.rotate(
              angle:
              (bearing - 90) *
                  math.pi /
                  180,
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        // Route lines.
        PolylineLayer(
          polylines: polylines,
        ),

        // Direction arrows.
        MarkerLayer(
          markers: arrows,
        ),
      ],
    );
  }

  double _calculateBearing(
      LatLng start,
      LatLng end,
      ) {
    final double deltaLon =
        end.longitude - start.longitude;

    final double deltaLat =
        end.latitude - start.latitude;

    final double angle = math.atan2(
      deltaLon,
      deltaLat,
    );

    return angle * 180 / math.pi;
  }
}