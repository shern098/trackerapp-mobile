import 'dart:developer';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads, caches, and parses GTFS static feeds from Malaysia's
/// official Open API (developer.data.gov.my/realtime-api/gtfs-static).
///
/// GTFS feeds are a ZIP of CSV files (routes.txt, trips.txt,
/// stop_times.txt, stops.txt), not JSON — so unlike Practical 10's
/// Weather API (http.get -> jsonDecode), this needs an extra unzip +
/// multi-file CSV parse step, cached to disk so it only happens once.
class GtfsService {
  static const _baseUrl = 'https://api.data.gov.my/gtfs-static/prasarana';

  // Downloads + unzips the feed for [category] (e.g. 'rapid-bus-kl') the
  // first time it's needed, then just reads the already-extracted files
  // on every call after that. Returns the folder containing the .txt files.
  Future<Directory> _ensureFeedReady(String category) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final feedDir = Directory('${docsDir.path}/gtfs/$category');

    // Cache check: if routes.txt is already there, assume the whole feed
    // was already downloaded and extracted — skip re-downloading.
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

  // Reads one GTFS .txt file (really just CSV) into a list of row-maps
  // keyed by the header row, e.g. {'route_id': '123', 'route_short_name': '300', ...}.
  Future<List<Map<String, dynamic>>> _readCsv(Directory feedDir, String filename) async {
    final file = File('${feedDir.path}/$filename');
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final rows = csv.decode(content);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    return rows.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();
  }

  // Converts a GTFS time string ("HH:MM:SS", where HH can exceed 24 for
  // trips that run past midnight) into total seconds — needed to
  // correctly calculate trip duration.
  int _timeToSeconds(String hhmmss) {
    final parts = hhmmss.trim().split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  /// Looks up a route by [query] within [category]. [matchLongName]=true
  /// matches against route_long_name (for train lines like "Kelana Jaya
  /// Line"); false matches route_short_name exactly (for bus numbers).
  ///
  /// Chains together 4 GTFS files to build one answer:
  /// routes.txt (find the route) -> trips.txt (pick one representative
  /// trip on that route) -> stop_times.txt (every stop on that trip, in
  /// order) -> stops.txt (turn stop_id codes into human-readable names).
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

    // 2. Find one representative trip for that route (a route can have
    // many trips throughout the day — we just need one to read its stops)
    final trips = await _readCsv(feedDir, 'trips.txt');
    final trip = trips.firstWhere(
      (t) => t['route_id'].toString() == routeId,
      orElse: () => {},
    );
    if (trip.isEmpty) return null;
    final tripId = trip['trip_id'].toString();

    // 3. Get every stop_time row for that trip, ordered by stop_sequence
    final stopTimes = await _readCsv(feedDir, 'stop_times.txt');
    final tripStopTimes = stopTimes
        .where((st) => st['trip_id'].toString() == tripId)
        .toList()
      ..sort((a, b) => int.parse(a['stop_sequence'].toString())
          .compareTo(int.parse(b['stop_sequence'].toString())));
    if (tripStopTimes.isEmpty) return null;

    // Trip duration = time of last stop's arrival minus first stop's departure
    final tripDurationMinutes = ((_timeToSeconds(
                tripStopTimes.last['arrival_time'].toString()) -
            _timeToSeconds(tripStopTimes.first['departure_time'].toString())) /
        60)
        .round();

    // 4. Map stop_id -> stop_name for just the stops on this trip
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

  /// Returns every route name in [category] — used to power the
  /// autocomplete suggestions in AddBusScreen/AddTrainScreen (e.g. typing
  /// "kel" suggests "Kelana Jaya"). [useLongName]=true returns
  /// route_long_name (for train lines); false returns route_short_name
  /// (for bus numbers). This reuses the same cached feed as lookupRoute()
  /// — no extra download if a lookup already happened first.
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
}

/// Plain result object for GtfsService.lookupRoute() — converted into
/// the screen-facing RouteInfo type by transit_api_service.dart.
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
