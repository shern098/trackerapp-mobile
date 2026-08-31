import 'dart:developer';
import 'gtfs_service.dart';

/// Called by Add Bus / Add Train to look up a route's static schedule
/// info (stop count, trip duration, stop names) once the user types in a
/// bus number or train line. Tries the real government GTFS feed first
/// (via GtfsService); if that fails for any reason (offline, feed
/// temporarily down, route not found), falls back to small hardcoded
/// values for "300" and "Kelana Jaya" so the app is still demoable.

/// The shape both AddBusScreen and AddTrainScreen actually consume —
/// kept identical whether the data came from the real feed or the mock
/// fallback, so the screens never need to know which source it came from.
class RouteInfo {
  final String label;
  final int stops;
  final int tripDurationMinutes;
  final List<String> stopNames;

  RouteInfo({
    required this.label,
    required this.stops,
    required this.tripDurationMinutes,
    required this.stopNames,
  });

  // Converts the real GTFS lookup result (GtfsRouteInfo) into this
  // screen-facing shape.
  factory RouteInfo.fromGtfs(GtfsRouteInfo info) => RouteInfo(
        label: info.label,
        stops: info.stops,
        tripDurationMinutes: info.tripDurationMinutes,
        stopNames: info.stopNames,
      );
}

class TransitApiService {
  final _gtfs = GtfsService();

  // Offline/fallback data only — used if the real feed can't be reached,
  // so the app still functions for a demo without internet access.
  static final Map<String, RouteInfo> _mockBusRoutes = {
    '300': RouteInfo(
      label: '300',
      stops: 46,
      tripDurationMinutes: 40,
      stopNames: ['Putrajaya Sentral', 'Hospital Putrajaya', '...'],
    ),
  };

  static final Map<String, RouteInfo> _mockTrainRoutes = {
    'kelana jaya': RouteInfo(
      label: 'Kelana Jaya',
      stops: 46,
      tripDurationMinutes: 120,
      stopNames: ['Putrajaya Sentral', 'Hospital Putrajaya', '...'],
    ),
  };

  // Called from AddBusScreen when the user looks up a bus number.
  Future<RouteInfo?> fetchBusInfo(String busNumber) async {
    try {
      final info = await _gtfs.lookupRoute(
        'rapid-bus-kl',
        busNumber,
        matchLongName: false, // bus numbers match route_short_name exactly
      );
      if (info != null) return RouteInfo.fromGtfs(info);
      log('No live match for bus "$busNumber", falling back to mock data if available.');
      return _mockBusRoutes[busNumber.trim()];
    } catch (e) {
      log('GTFS lookup failed ($e), falling back to mock data.');
      return _mockBusRoutes[busNumber.trim()];
    }
  }

  // Called from AddTrainScreen when the user looks up a train line.
  Future<RouteInfo?> fetchTrainInfo(String lineName) async {
    try {
      final info = await _gtfs.lookupRoute(
        'rapid-rail-kl',
        lineName,
        matchLongName: true, // e.g. "Kelana Jaya" matches "Kelana Jaya Line"
      );
      if (info != null) return RouteInfo.fromGtfs(info);
      log('No live match for line "$lineName", falling back to mock data if available.');
      return _mockTrainRoutes[lineName.trim().toLowerCase()];
    } catch (e) {
      log('GTFS lookup failed ($e), falling back to mock data.');
      return _mockTrainRoutes[lineName.trim().toLowerCase()];
    }
  }

  // Full list of known bus numbers, for AddBusScreen's autocomplete
  // suggestions as the user types. Falls back to just the mock numbers
  // if the real feed can't be reached.
  Future<List<String>> listBusNumbers() async {
    try {
      return await _gtfs.listRouteNames('rapid-bus-kl', useLongName: false);
    } catch (e) {
      log('Could not load live bus number list ($e), falling back to mock data.');
      return _mockBusRoutes.values.map((r) => r.label).toList();
    }
  }

  // Full list of known train line names, for AddTrainScreen's
  // autocomplete suggestions — e.g. typing "kel" should suggest
  // "Kelana Jaya Line".
  Future<List<String>> listTrainLines() async {
    try {
      return await _gtfs.listRouteNames('rapid-rail-kl', useLongName: true);
    } catch (e) {
      log('Could not load live train line list ($e), falling back to mock data.');
      return _mockTrainRoutes.values.map((r) => r.label).toList();
    }
  }
}
