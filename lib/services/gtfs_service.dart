import 'dart:developer';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class GtfsService {
  static const _baseUrl = 'https://api.data.gov.my/gtfs-static/prasarana';

  final Map<String, List<Map<String, dynamic>>> _csvCache = {};

  Future<Directory> _ensureFeedReady(String category) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final feedDir = Directory('${docsDir.path}/gtfs/$category');

    final routesFile = File('${feedDir.path}/routes.txt');
    if (await routesFile.exists()) {
      return feedDir;
    }

    log('Downloading GTFS feed for $category...');
    final response = await http.get(Uri.parse('$_baseUrl?category=$category'));
    if (response.statusCode != 200) {
      throw Exception('Failed to download GTFS feed: ${response.statusCode}');
    }

    await feedDir.create(recursive: true);
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    for (final file in archive) {
      if (file.isFile) {
        final outFile = File('${feedDir.path}/${file.name}');
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
    log('GTFS feed for $category extracted to ${feedDir.path}');
    return feedDir;
  }

  Future<List<Map<String, dynamic>>> _readCsv(Directory feedDir, String filename) async {
    final cacheKey = '${feedDir.path}/$filename';
    final cached = _csvCache[cacheKey];
    if (cached != null) return cached;

    final file = File(cacheKey);
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final rows = csv.decode(content);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final parsed = rows.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();

    _csvCache[cacheKey] = parsed;
    return parsed;
  }

  int _timeToSeconds(String hhmmss) {
    final parts = hhmmss.trim().split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  Future<GtfsRouteInfo?> lookupRoute(
    String category,
    String query, {
    required bool matchLongName,
  }) async {
    final feedDir = await _ensureFeedReady(category);

    // 1. Find the matching route
    final routes = await _readCsv(feedDir, 'routes.txt');
    final normalizedQuery = query.trim().toLowerCase();
    final route = routes.firstWhere(
      (r) => matchLongName
          ? (r['route_long_name']?.toString().toLowerCase() ?? '')
              .contains(normalizedQuery)
          : (r['route_short_name']?.toString().toLowerCase() ?? '') ==
              normalizedQuery,
      orElse: () => {},
    );
    if (route.isEmpty) return null;
    final routeId = route['route_id'].toString();
    final label = matchLongName
        ? (route['route_long_name']?.toString() ?? query)
        : (route['route_short_name']?.toString() ?? query);

    final trips = await _readCsv(feedDir, 'trips.txt');
    final trip = trips.firstWhere(
      (t) => t['route_id'].toString() == routeId,
      orElse: () => {},
    );
    if (trip.isEmpty) return null;
    final tripId = trip['trip_id'].toString();

    final stopTimes = await _readCsv(feedDir, 'stop_times.txt');
    final tripStopTimes = stopTimes
        .where((st) => st['trip_id'].toString() == tripId)
        .toList()
      ..sort((a, b) => int.parse(a['stop_sequence'].toString())
          .compareTo(int.parse(b['stop_sequence'].toString())));
    if (tripStopTimes.isEmpty) return null;

    final tripDurationMinutes = ((_timeToSeconds(
                tripStopTimes.last['arrival_time'].toString()) -
            _timeToSeconds(tripStopTimes.first['departure_time'].toString())) /
        60)
        .round();

    final stops = await _readCsv(feedDir, 'stops.txt');
    final stopNameById = {
      for (final s in stops) s['stop_id'].toString(): s['stop_name'].toString()
    };
    final stopNames = tripStopTimes
        .map((st) => stopNameById[st['stop_id'].toString()] ?? st['stop_id'].toString())
        .toList();

    return GtfsRouteInfo(
      label: label,
      stops: stopNames.length,
      tripDurationMinutes: tripDurationMinutes < 0 ? 0 : tripDurationMinutes,
      stopNames: stopNames,
    );
  }

  Future<List<String>> listRouteNames(String category, {required bool useLongName}) async {
    final feedDir = await _ensureFeedReady(category);
    final routes = await _readCsv(feedDir, 'routes.txt');
    return routes
        .map((r) => useLongName ? r['route_long_name'] : r['route_short_name'])
        .where((name) => name != null && name.toString().trim().isNotEmpty)
        .map((name) => name.toString())
        .toSet() // some feeds repeat the same short/long name across multiple route_id rows
        .toList();
  }

  Future<List<LatLng>> getRouteShapePoints(
    String category,
    String query, {
    required bool matchLongName,
  }) async {
    final feedDir = await _ensureFeedReady(category);

    final routes = await _readCsv(feedDir, 'routes.txt');
    final normalizedQuery = query.trim().toLowerCase();
    final route = routes.firstWhere(
      (r) => matchLongName
          ? (r['route_long_name']?.toString().toLowerCase() ?? '')
              .contains(normalizedQuery)
          : (r['route_short_name']?.toString().toLowerCase() ?? '') ==
              normalizedQuery,
      orElse: () => {},
    );
    if (route.isEmpty) return [];
    final routeId = route['route_id'].toString();

    final trips = await _readCsv(feedDir, 'trips.txt');
    final trip = trips.firstWhere(
      (t) => t['route_id'].toString() == routeId,
      orElse: () => {},
    );
    if (trip.isEmpty) return [];
    final tripId = trip['trip_id'].toString();
    final shapeId = trip['shape_id']?.toString();

    // --- Preferred path: real shapes.txt data ---
    if (shapeId != null && shapeId.isNotEmpty) {
      final shapes = await _readCsv(feedDir, 'shapes.txt');
      final points = shapes.where((s) => s['shape_id'].toString() == shapeId).toList()
        ..sort((a, b) => int.parse(a['shape_pt_sequence'].toString())
            .compareTo(int.parse(b['shape_pt_sequence'].toString())));

      if (points.isNotEmpty) {
        return points
            .map((p) => LatLng(
                  double.parse(p['shape_pt_lat'].toString()),
                  double.parse(p['shape_pt_lon'].toString()),
                ))
            .toList();
      }
    }

    final stopTimes = await _readCsv(feedDir, 'stop_times.txt');
    final tripStopTimes = stopTimes.where((st) => st['trip_id'].toString() == tripId).toList()
      ..sort((a, b) => int.parse(a['stop_sequence'].toString())
          .compareTo(int.parse(b['stop_sequence'].toString())));
    if (tripStopTimes.isEmpty) return [];

    final stops = await _readCsv(feedDir, 'stops.txt');
    final stopById = {for (final s in stops) s['stop_id'].toString(): s};

    return tripStopTimes
        .map((st) => stopById[st['stop_id'].toString()])
        .where((stop) => stop != null && stop['stop_lat'] != null && stop['stop_lon'] != null)
        .map((stop) => LatLng(
              double.parse(stop!['stop_lat'].toString()),
              double.parse(stop['stop_lon'].toString()),
            ))
        .toList();
  }
}

class GtfsRouteInfo {
  final String label;
  final int stops;
  final int tripDurationMinutes;
  final List<String> stopNames;

  GtfsRouteInfo({
    required this.label,
    required this.stops,
    required this.tripDurationMinutes,
    required this.stopNames,
  });
}
