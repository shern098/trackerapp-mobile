import 'package:latlong2/latlong.dart';

import '../models/route.dart';
import '../models/bus_stop.dart';
import '../models/trip.dart';
import '../models/shape_point.dart';

import '../utils/gtfs_csv_reader.dart';

// get things relevant things from models

class GtfsStaticService {
  final String directory;

  GtfsStaticService({
    required this.directory,
  });

  Future<List<Map<String, String>>> _read(
      String filename,
      ) {
    return GtfsCsvReader.read(
      '$directory/$filename',
    );
  }

  Future<GtfsRoute?> getRoute(
      String routeId,
      ) async {
    final rows = await _read('routes.txt');

    for (final row in rows) {
      if (row['route_id'] == routeId) {
        return GtfsRoute(
          id: row['route_id'] ?? '',
          agencyId: row['agency_id'] ?? '',
          shortName: row['route_short_name'] ?? '',
          longName: row['route_long_name'] ?? '',
          type: int.tryParse(
            row['route_type'] ?? '',
          ) ??
              0,
          color: row['route_color'] ?? '',
          textColor:
          row['route_text_color'] ?? '',
        );
      }
    }

    return null;
  }

  Future<List<GtfsRoute>> getRoutes() async {
    final rows = await _read('routes.txt');

    final routes = <GtfsRoute>[];

    for (final row in rows) {
      routes.add(
        GtfsRoute(
          id: row['route_id'] ?? '',
          agencyId: row['agency_id'] ?? '',
          shortName:
          row['route_short_name'] ?? '',
          longName:
          row['route_long_name'] ?? '',
          type:
          int.tryParse(
            row['route_type'] ?? '',
          ) ??
              0,
          color:
          row['route_color'] ?? '',
          textColor:
          row['route_text_color'] ?? '',
        ),
      );
    }

    return routes;
  }

  Future<List<Trip>> getTripsForRoute(
      String routeId,
      ) async {
    final rows = await _read('trips.txt');

    final trips = <Trip>[];

    for (final row in rows) {
      if (row['route_id'] != routeId) {
        continue;
      }

      trips.add(
        Trip(
          routeId: row['route_id'] ?? '',
          serviceId: row['service_id'] ?? '',
          tripId: row['trip_id'] ?? '',
          shapeId: row['shape_id'] ?? '',
          headsign:
          row['trip_headsign'] ?? '',
          directionId:
          row['direction_id'] ?? '',
        ),
      );
    }

    return trips;
  }

  Future<List<ShapePoint>> getShape(
      String shapeId,
      ) async {
    final rows = await _read('shapes.txt');

    final points = <ShapePoint>[];

    for (final row in rows) {
      if (row['shape_id'] != shapeId) {
        continue;
      }

      final lat =
      double.tryParse(
        row['shape_pt_lat'] ?? '',
      );

      final lon =
      double.tryParse(
        row['shape_pt_lon'] ?? '',
      );

      final sequence =
      int.tryParse(
        row['shape_pt_sequence'] ?? '',
      );

      if (lat == null ||
          lon == null ||
          sequence == null) {
        continue;
      }

      points.add(
        ShapePoint(
          shapeId: shapeId,
          position: LatLng(lat, lon),
          sequence: sequence,
        ),
      );
    }

    points.sort(
          (a, b) => a.sequence.compareTo(
        b.sequence,
      ),
    );

    return points;
  }

  Future<List<BusStop>> getStopsForTrip(
      String tripId,
      ) async {
    final stopTimeRows =
    await _read('stop_times.txt');

    final stopIds = <String>[];

    for (final row in stopTimeRows) {
      if (row['trip_id'] == tripId) {
        final stopId =
            row['stop_id'] ?? '';

        if (stopId.isNotEmpty) {
          stopIds.add(stopId);
        }
      }
    }

    if (stopIds.isEmpty) {
      return [];
    }

    final stopRows =
    await _read('stops.txt');

    final stops = <BusStop>[];

    for (final row in stopRows) {
      final stopId =
          row['stop_id'] ?? '';

      if (!stopIds.contains(stopId)) {
        continue;
      }

      final lat =
      double.tryParse(
        row['stop_lat'] ?? '',
      );

      final lon =
      double.tryParse(
        row['stop_lon'] ?? '',
      );

      if (lat == null || lon == null) {
        continue;
      }

      stops.add(
        BusStop(
          id: stopId,
          name:
          row['stop_name'] ?? '',
          description:
          row['stop_desc'] ?? '',
          position: LatLng(
            lat,
            lon,
          ),
        ),
      );
    }

    return stops;
  }
}