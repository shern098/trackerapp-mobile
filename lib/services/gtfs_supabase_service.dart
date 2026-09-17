import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route.dart';

class GtfsSupabaseService {
  final SupabaseClient _client;

  GtfsSupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const int _busRouteType = 3;

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
}