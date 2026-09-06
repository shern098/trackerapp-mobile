import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RouteLookupService {
  static const _baseUrl = 'https://api.data.gov.my/gtfs-static/prasarana';

  final Map<String, List<Map<String, dynamic>>> _cachedRows = {};
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
      content = utf8.decode(routesEntry.content as List<int>);
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

  Future<String?> shortNameForRouteId(String category, String routeId) async {
    final rows = await _ensureRowsLoaded(category);

    final match = rows.firstWhere(
          (r) => r['route_id'].toString() == routeId,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      final shortName = match['route_short_name']?.toString();
      if (shortName != null && shortName.trim().isNotEmpty) return shortName;
      final longName = match['route_long_name']?.toString();
      if (longName != null && longName.trim().isNotEmpty) return longName;
    }

    final fallback = rows.firstWhere(
          (r) =>
      r['route_short_name'].toString() == routeId ||
          r['route_long_name'].toString() == routeId,
      orElse: () => {},
    );
    if (fallback.isEmpty) return null;

    final shortName = fallback['route_short_name']?.toString();
    if (shortName != null && shortName.trim().isNotEmpty) return shortName;
    return fallback['route_long_name']?.toString();
  }
}
