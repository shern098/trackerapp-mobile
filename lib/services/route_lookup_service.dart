import 'dart:developer';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Translates a raw route_id from the GTFS-Realtime feed into a
/// human-readable bus number (e.g. "300") — used when a live map marker
/// is tapped. Built on a lightweight parse of just routes.txt from the
/// GTFS static feed (much smaller than the full parse in
/// gtfs_service.dart, which also needs trips.txt, stop_times.txt, and
/// stops.txt).
class RouteLookupService {
  static const _baseUrl = 'https://api.data.gov.my/gtfs-static/prasarana';

  // In-memory cache per category for the current app session — avoids
  // re-parsing the CSV on every keystroke/tap.
  final Map<String, List<Map<String, dynamic>>> _cachedRows = {};

  // Downloads (first time only) and parses routes.txt into raw row-maps,
  // one per route (keyed by column name, e.g. {'route_id': '123',
  // 'route_short_name': '300', 'route_long_name': '...'}). Caches the
  // raw file to disk too, so even after an app restart we don't need to
  // re-download — just re-parse the already-saved file.
  Future<List<Map<String, dynamic>>> _ensureRowsLoaded(String category) async {
    if (_cachedRows.containsKey(category)) return _cachedRows[category]!;

    final docsDir = await getApplicationDocumentsDirectory();
    final routesFile = File('${docsDir.path}/gtfs_routes_$category.txt');

    String content;
    if (await routesFile.exists()) {
      content = await routesFile.readAsString();
    } else {
      log('Downloading GTFS feed for $category (to extract routes.txt only)...');
      final response = await http.get(Uri.parse('$_baseUrl?category=$category'));
      if (response.statusCode != 200) {
        throw Exception('Failed to download GTFS feed: ${response.statusCode}');
      }
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      final routesEntry = archive.files.firstWhere(
        (f) => f.name == 'routes.txt',
        orElse: () => throw Exception('routes.txt not found in feed'),
      );
      content = String.fromCharCodes(routesEntry.content as List<int>);
      await routesFile.writeAsString(content); // cache to disk so we only ever download once
    }

    final rows = csv.decode(content);
    if (rows.isEmpty) {
      _cachedRows[category] = [];
      return [];
    }
    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final parsed = rows.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();

    _cachedRows[category] = parsed;
    log('Loaded ${parsed.length} routes for $category');
    return parsed;
  }

  /// Returns the human-readable bus number (e.g. "300") for a raw
  /// route_id from the realtime feed. Returns null if no match is found
  /// (e.g. the realtime and static feeds have drifted out of sync for
  /// that particular route).
  Future<String?> shortNameForRouteId(String category, String routeId) async {
    final rows = await _ensureRowsLoaded(category);
    final match = rows.firstWhere(
      (r) => r['route_id'].toString() == routeId,
      orElse: () => {},
    );
    if (match.isEmpty) return null;
    return match['route_short_name']?.toString();
  }
}
