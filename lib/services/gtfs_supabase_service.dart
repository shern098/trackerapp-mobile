import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/route.dart';
import '../models/trip.dart';
import '../models/shape_point.dart';
import '../models/bus_stop.dart';

class GtfsSupabaseService {
  final SupabaseClient _client;

  GtfsSupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const int _busRouteType = 3;
  static const String trainFeedCategory = 'rapid-rail-kl';

  // ============================================================
  // BUS — route catalog (unchanged)
  // ============================================================

  Future<List<String>> getFeedCategories() async {
    final rows = await _client
        .from('gtfs_routes')
        .select('feed_category')
        .eq('route_type', _busRouteType);

    final categories = <String>{};
    for (final row in rows as List) {
      final value = (row as Map)['feed_category']?.toString();
      if (value != null && value.isNotEmpty) categories.add(value);
    }
    return categories.toList()..sort();
  }

  Future<List<GtfsRoute>> getRoutes({required String feedCategory}) async {
    final rows = await _client
        .from('gtfs_routes')
        .select()
        .eq('feed_category', feedCategory)
        .eq('route_type', _busRouteType)
        .order('route_short_name');

    return (rows as List)
        .map((row) => GtfsRoute.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<GtfsRoute>> getRoutesByKeys(List<String> keys) async {
    if (keys.isEmpty) return [];

    final feedCategories = <String>{};
    final routeIds = <String>{};
    for (final key in keys) {
      final parts = key.split('|');
      if (parts.length != 2) continue;
      feedCategories.add(parts[0]);
      routeIds.add(parts[1]);
    }
    if (feedCategories.isEmpty || routeIds.isEmpty) return [];

    final rows = await _client
        .from('gtfs_routes')
        .select()
        .inFilter('feed_category', feedCategories.toList())
        .inFilter('route_id', routeIds.toList())
        .eq('route_type', _busRouteType);

    final all = (rows as List)
        .map((row) => GtfsRoute.fromMap(row as Map<String, dynamic>))
        .toList();

    final keySet = keys.toSet();
    return all.where((route) => keySet.contains(route.uniqueKey)).toList();
  }

  // ============================================================
  // TRAIN — route catalog (single feed: rapid-rail-kl)
  // ============================================================

  Future<List<GtfsRoute>> getTrainRoutes() async {
    final rows = await _client
        .from('gtfs_routes')
        .select()
        .eq('feed_category', trainFeedCategory)
        .order('route_short_name');

    return (rows as List)
        .map((row) => GtfsRoute.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<GtfsRoute>> getTrainRoutesByKeys(List<String> keys) async {
    if (keys.isEmpty) return [];

    final routeIds = <String>{};
    for (final key in keys) {
      final parts = key.split('|');
      if (parts.length == 2 && parts[0] == trainFeedCategory) {
        routeIds.add(parts[1]);
      }
    }
    if (routeIds.isEmpty) return [];

    final rows = await _client
        .from('gtfs_routes')
        .select()
        .eq('feed_category', trainFeedCategory)
        .inFilter('route_id', routeIds.toList());

    return (rows as List)
        .map((row) => GtfsRoute.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // GENERIC — used by MapScreen to render a route's shape/stops
  // for any feed (currently used for train; bus still uses the
  // bundled local GTFS files).
  // ============================================================

  Future<GtfsRoute?> getRouteByFeedAndId(
      String feedCategory, String routeId) async {
    final rows = await _client
        .from('gtfs_routes')
        .select()
        .eq('feed_category', feedCategory)
        .eq('route_id', routeId)
        .limit(1);

    final list = rows as List;
    if (list.isEmpty) return null;
    return GtfsRoute.fromMap(list.first as Map<String, dynamic>);
  }

  Future<List<Trip>> getTripsForRoute(
      String feedCategory, String routeId) async {
    final rows = await _client
        .from('gtfs_trips')
        .select()
        .eq('feed_category', feedCategory)
        .eq('route_id', routeId);

    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      return Trip(
        routeId: map['route_id']?.toString() ?? '',
        serviceId: map['service_id']?.toString() ?? '',
        tripId: map['trip_id']?.toString() ?? '',
        shapeId: map['shape_id']?.toString() ?? '',
        headsign: map['trip_headsign']?.toString() ?? '',
        directionId: map['direction_id']?.toString() ?? '',
      );
    }).toList();
  }

  Future<List<ShapePoint>> getShape(
      String feedCategory, String shapeId) async {
    final rows = await _client
        .from('gtfs_shapes')
        .select()
        .eq('feed_category', feedCategory)
        .eq('shape_id', shapeId)
        .order('shape_pt_sequence');

    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      return ShapePoint(
        shapeId: shapeId,
        position: LatLng(
          (map['shape_pt_lat'] as num).toDouble(),
          (map['shape_pt_lon'] as num).toDouble(),
        ),
        sequence: map['shape_pt_sequence'] as int,
      );
    }).toList();
  }

  Future<List<BusStop>> getStopsForTrip(
      String feedCategory, String tripId) async {
    final stopTimeRows = await _client
        .from('gtfs_stop_times')
        .select('stop_id')
        .eq('feed_category', feedCategory)
        .eq('trip_id', tripId);

    final stopIds = (stopTimeRows as List)
        .map((row) => (row as Map)['stop_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (stopIds.isEmpty) return [];

    final stopRows = await _client
        .from('gtfs_stops')
        .select()
        .eq('feed_category', feedCategory)
        .inFilter('stop_id', stopIds);

    return (stopRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      return BusStop(
        id: map['stop_id']?.toString() ?? '',
        name: map['stop_name']?.toString() ?? '',
        description: map['stop_desc']?.toString() ?? '',
        position: LatLng(
          (map['stop_lat'] as num).toDouble(),
          (map['stop_lon'] as num).toDouble(),
        ),
      );
    }).toList();
  }
}