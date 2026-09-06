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

  // Called from AddBusScreen when the user looks up a bus number.
  Future<RouteInfo?> fetchBusInfo(String busNumber) async {
    try {
      final info = await _gtfs.lookupRoute(
        'rapid-bus-kl',
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

  // Called from AddTrainScreen when the user looks up a train line.
  Future<RouteInfo?> fetchTrainInfo(String lineName) async {
    try {
      final info = await _gtfs.lookupRoute(
        'rapid-rail-kl',
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

  Future<List<String>?> listBusNumbers() async {
    try {
      return await _gtfs.listRouteNames('rapid-bus-kl', useLongName: false);
    } catch (e) {
      log('Could not load live bus number list ($e.');
      return null;
    }
  }

  Future<List<String>?>listTrainLines() async {
    try {
      return await _gtfs.listRouteNames('rapid-rail-kl', useLongName: true);
    } catch (e) {
      log('Could not load live train line list ($e).');
      return null;
    }
  }

  Future<List<LatLng>> fetchBusRouteShape(String busNumber) async {
    try {
      return await _gtfs.getRouteShapePoints('rapid-bus-kl', busNumber, matchLongName: false);
    } catch (e) {
      log('Could not load route shape for bus "$busNumber" ($e).');
      return [];
    }
  }

  Future<List<LatLng>> fetchTrainRouteShape(String lineName) async {
    try {
      return await _gtfs.getRouteShapePoints('rapid-rail-kl', lineName, matchLongName: true);
    } catch (e) {
      log('Could not load route shape for train line "$lineName" ($e).');
      return [];
    }
  }
}
