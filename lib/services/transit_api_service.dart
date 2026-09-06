import 'dart:developer';
import 'package:latlong2/latlong.dart';
import 'gtfs_service.dart';

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

  factory RouteInfo.fromGtfs(GtfsRouteInfo info) => RouteInfo(
        label: info.label,
        stops: info.stops,
        tripDurationMinutes: info.tripDurationMinutes,
        stopNames: info.stopNames,
      );
}

class TransitApiService {
  final _gtfs = GtfsService();

  Future<RouteInfo?> fetchBusInfo(String busNumber, {String category= 'rapid-bus-kl'}) async {
    try {
      final info = await _gtfs.lookupRoute(
        category,
        busNumber,
        matchLongName: false,
      );
      if (info != null) return RouteInfo.fromGtfs(info);
      log('No live match for bus "$busNumber".');
      return null;
    } catch (e) {
      log('GTFS lookup failed ($e).');
      return null;
    }
  }

  Future<RouteInfo?> fetchTrainInfo(String lineName, {String category = 'rapid-rail-kl'}) async {
    try {
      final info = await _gtfs.lookupRoute(
        category,
        lineName,
        matchLongName: true,
      );
      if (info != null) return RouteInfo.fromGtfs(info);
      log('No live match for line "$lineName".');
      return null;
    } catch (e) {
      log('GTFS lookup failed ($e).');
      return null;

    }
  }

  Future<List<String>?> listBusNumbers({String category = 'rapid-bus-kl'}) async {
    try {
      return await _gtfs.listRouteNames(category, useLongName: false);
    } catch (e) {
      log('Could not load live bus number list for $category ($e).');
      return null;
    }
  }

  Future<List<String>?> listTrainLines({String category = 'rapid-rail-kl'}) async {
    try {
      return await _gtfs.listRouteNames(category, useLongName: true);
    } catch (e) {
      log('Could not load live train line list for $category ($e).');
      return null;
    }
  }

  Future<List<LatLng>> fetchBusRouteShape(String busNumber, {String category = 'rapid-bus-kl'}) async {
    try {
      return await _gtfs.getRouteShapePoints(category, busNumber, matchLongName: false);
    } catch (e) {
      log('Could not load route shape for bus "$busNumber" in $category ($e).');
      return [];
    }
  }

  Future<List<LatLng>> fetchTrainRouteShape(String lineName, {String category = 'rapid-rail-kl'}) async {
    try {
      return await _gtfs.getRouteShapePoints(category, lineName, matchLongName: true);
    } catch (e) {
      log('Could not load route shape for train line "$lineName" in $category ($e).');
      return [];
    }
  }
}
