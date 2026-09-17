// import 'package:http/http.dart' as http;
// import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';
// import 'package:latlong2/latlong.dart';
//
// import '../models/vehicle.dart';
//
// class TransportApi {
//   static const String _url =
//       'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana'
//       '?category=rapid-bus-kl';
//
//   Future<List<Vehicle>> fetchVehicles() async {
//     final response = await http.get(Uri.parse(_url));
//
//     print('');
//     print('========================================');
//     print('FETCH');
//     print('HTTP status: ${response.statusCode}');
//     print('Bytes received: ${response.bodyBytes.length}');
//
//     if (response.statusCode != 200) {
//       throw Exception(
//         'GTFS API request failed: ${response.statusCode}',
//       );
//     }
//
//     final feed = FeedMessage();
//     feed.mergeFromBuffer(response.bodyBytes);
//
//     print('Entities received: ${feed.entity.length}');
//     print('========================================');
//
//     final List<Vehicle> vehicles = [];
//
//     for (final entity in feed.entity) {
//       if (!entity.hasVehicle()) {
//         continue;
//       }
//
//       final vehiclePosition = entity.vehicle;
//
//       if (!vehiclePosition.hasPosition()) {
//         continue;
//       }
//
//       final routeId = vehiclePosition.hasTrip()
//           ? vehiclePosition.trip.routeId
//           : '';
//
//       final tripId = vehiclePosition.hasTrip()
//           ? vehiclePosition.trip.tripId
//           : '';
//
//       final vehicleId = vehiclePosition.hasVehicle()
//           ? vehiclePosition.vehicle.id
//           : entity.id;
//
//       // Determine vehicle type from route ID.
//       final VehicleType type =
//       routeId.startsWith('T')
//           ? VehicleType.train
//           : VehicleType.bus;
//
//       final vehicle = Vehicle(
//         id: vehicleId,
//         routeId: routeId,
//         tripId: tripId,
//         type: type,
//         position: LatLng(
//           vehiclePosition.position.latitude,
//           vehiclePosition.position.longitude,
//         ),
//         speed: vehiclePosition.position.speed,
//         bearing: vehiclePosition.position.bearing,
//         timestamp: vehiclePosition.hasTimestamp()
//             ? vehiclePosition.timestamp.toInt()
//             : 0,
//       );
//
//       vehicles.add(vehicle);
//
//       print(
//         '${vehicle.type.name.toUpperCase()} '
//             '${vehicle.id} | '
//             '${vehicle.routeId} | '
//             '${vehicle.position.latitude}, '
//             '${vehicle.position.longitude}',
//       );
//     }
//
//     return vehicles;
//   }
// }








// import 'dart:convert';
//
// import 'package:http/http.dart' as http;
// import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';
// import 'package:latlong2/latlong.dart';
//
// import '../models/vehicle.dart';
//
// class TransportApi {
//   static const String _url =
//       'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana'
//       '?category=rapid-bus-kl';
//
//   Future<List<Vehicle>> fetchVehicles() async {
//     print('');
//     print('');
//     print('============================================================');
//     print('                 TRANSPORT API DEBUG');
//     print('============================================================');
//     print('REQUEST URL:');
//     print(_url);
//     print('------------------------------------------------------------');
//
//     try {
//       // ---------------------------------------------------------
//       // SEND REQUEST
//       // ---------------------------------------------------------
//       final response = await http.get(Uri.parse(_url));
//
//       print('');
//       print('==================== HTTP RESPONSE ========================');
//       print('Status Code : ${response.statusCode}');
//       print('Reason      : ${response.reasonPhrase}');
//       print('Content-Type: ${response.headers['content-type']}');
//       print('Content-Length: ${response.headers['content-length']}');
//       print('Bytes       : ${response.bodyBytes.length}');
//
//       print('');
//       print('==================== RESPONSE HEADERS =====================');
//       response.headers.forEach((key, value) {
//         print('$key: $value');
//       });
//
//       // ---------------------------------------------------------
//       // CHECK HTTP STATUS
//       // ---------------------------------------------------------
//       if (response.statusCode != 200) {
//         print('');
//         print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
//         print('API REQUEST FAILED');
//         print('HTTP STATUS: ${response.statusCode}');
//         print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
//
//         // Try to print response as text in case the API
//         // returned an error message.
//         print('');
//         print('ERROR RESPONSE BODY:');
//
//         try {
//           print(utf8.decode(response.bodyBytes));
//         } catch (e) {
//           print('Could not decode response as UTF-8.');
//           print('Raw bytes:');
//           print(response.bodyBytes);
//         }
//
//         throw Exception(
//           'GTFS API request failed: ${response.statusCode}',
//         );
//       }
//
//       // ---------------------------------------------------------
//       // RAW RESPONSE
//       // ---------------------------------------------------------
//       print('');
//       print('==================== RAW RESPONSE =========================');
//       print('Response is GTFS-Realtime Protocol Buffer data.');
//       print('Raw byte count: ${response.bodyBytes.length}');
//
//       print('');
//       print('First 100 bytes:');
//
//       final firstBytes = response.bodyBytes.take(100).toList();
//
//       print(firstBytes);
//
//       // Do NOT print the entire response.body as text.
//       //
//       // GTFS-Realtime is Protocol Buffer binary data, so it will
//       // usually contain unreadable characters if printed as text.
//       //
//       // The decoded GTFS information is printed below instead.
//
//       // ---------------------------------------------------------
//       // DECODE GTFS REALTIME FEED
//       // ---------------------------------------------------------
//       print('');
//       print('==================== GTFS DECODING =========================');
//
//       final feed = FeedMessage();
//
//       try {
//         feed.mergeFromBuffer(response.bodyBytes);
//
//         print('GTFS feed decoded successfully.');
//       } catch (e, stackTrace) {
//         print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
//         print('GTFS DECODING FAILED');
//         print('Error: $e');
//         print('Stack trace:');
//         print(stackTrace);
//         print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
//
//         rethrow;
//       }
//
//       // ---------------------------------------------------------
//       // FEED HEADER
//       // ---------------------------------------------------------
//       print('');
//       print('==================== FEED HEADER ===========================');
//
//       print('Header exists: ${feed.hasHeader()}');
//
//       if (feed.hasHeader()) {
//         print('GTFS Version: ${feed.header.gtfsRealtimeVersion}');
//         print('Incrementality: ${feed.header.incrementality}');
//         print('Timestamp: ${feed.header.hasTimestamp()
//             ? feed.header.timestamp
//             : 'N/A'}');
//       }
//
//       // ---------------------------------------------------------
//       // ENTITY COUNT
//       // ---------------------------------------------------------
//       print('');
//       print('==================== ENTITIES ==============================');
//
//       print('Total entities received: ${feed.entity.length}');
//
//       if (feed.entity.isEmpty) {
//         print('');
//         print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
//         print('WARNING: API RETURNED ZERO ENTITIES');
//         print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
//       }
//
//       final List<Vehicle> vehicles = [];
//
//       // ---------------------------------------------------------
//       // PROCESS EVERY ENTITY
//       // ---------------------------------------------------------
//       for (int i = 0; i < feed.entity.length; i++) {
//         final entity = feed.entity[i];
//
//         print('');
//         print('************************************************************');
//         print('ENTITY #${i + 1}');
//         print('************************************************************');
//
//         print('Entity ID: ${entity.id}');
//         print('Has Vehicle: ${entity.hasVehicle()}');
//         print('Has Trip Update: ${entity.hasTripUpdate()}');
//         print('Has Alert: ${entity.hasAlert()}');
//
//         // -------------------------------------------------------
//         // VEHICLE
//         // -------------------------------------------------------
//         if (!entity.hasVehicle()) {
//           print('');
//           print('This entity does NOT contain vehicle information.');
//           continue;
//         }
//
//         final vehiclePosition = entity.vehicle;
//
//         print('');
//         print('---------------- VEHICLE DATA ----------------');
//
//         print(
//           'Vehicle ID: ${vehiclePosition.hasVehicle()
//               ? vehiclePosition.vehicle.id
//               : 'N/A'}',
//         );
//
//         print(
//           'Vehicle Label: ${vehiclePosition.hasVehicle()
//               ? vehiclePosition.vehicle.label
//               : 'N/A'}',
//         );
//
//         print(
//           'Vehicle License Plate: ${vehiclePosition.hasVehicle()
//               ? vehiclePosition.vehicle.licensePlate
//               : 'N/A'}',
//         );
//
//         // -------------------------------------------------------
//         // TRIP
//         // -------------------------------------------------------
//         print('');
//         print('---------------- TRIP DATA -------------------');
//
//         print('Has Trip: ${vehiclePosition.hasTrip()}');
//
//         String routeId = '';
//         String tripId = '';
//
//         if (vehiclePosition.hasTrip()) {
//           routeId = vehiclePosition.trip.routeId;
//           tripId = vehiclePosition.trip.tripId;
//
//           print('Route ID: $routeId');
//           print('Trip ID: $tripId');
//           print('Direction ID: ${vehiclePosition.trip.hasDirectionId()
//               ? vehiclePosition.trip.directionId
//               : 'N/A'}');
//           print('Start Time: ${vehiclePosition.trip.startTime}');
//           print('Start Date: ${vehiclePosition.trip.startDate}');
//           print('Schedule Relationship: '
//               '${vehiclePosition.trip.scheduleRelationship}');
//         } else {
//           print('No trip information available.');
//         }
//
//         // -------------------------------------------------------
//         // POSITION
//         // -------------------------------------------------------
//         print('');
//         print('---------------- POSITION DATA ----------------');
//
//         print('Has Position: ${vehiclePosition.hasPosition()}');
//
//         if (!vehiclePosition.hasPosition()) {
//           print('NO POSITION DATA - VEHICLE WILL NOT BE ADDED.');
//           continue;
//         }
//
//         final position = vehiclePosition.position;
//
//         print('Latitude : ${position.latitude}');
//         print('Longitude: ${position.longitude}');
//         print('Bearing  : ${position.bearing}');
//         print('Speed    : ${position.speed}');
//         print('Odometer : ${position.odometer}');
//
//         // -------------------------------------------------------
//         // CURRENT STOP / STATUS
//         // -------------------------------------------------------
//         print('');
//         print('---------------- STATUS DATA ------------------');
//
//         print(
//           'Current Stop Sequence: '
//               '${vehiclePosition.hasCurrentStopSequence()
//               ? vehiclePosition.currentStopSequence
//               : 'N/A'}',
//         );
//
//         print(
//           'Current Stop ID: '
//               '${vehiclePosition.hasStopId()
//               ? vehiclePosition.stopId
//               : 'N/A'}',
//         );
//
//         print(
//           'Current Status: '
//               '${vehiclePosition.hasCurrentStatus()
//               ? vehiclePosition.currentStatus
//               : 'N/A'}',
//         );
//
//         // -------------------------------------------------------
//         // TIMESTAMP
//         // -------------------------------------------------------
//         print('');
//         print('---------------- TIMESTAMP --------------------');
//
//         if (vehiclePosition.hasTimestamp()) {
//           print('Timestamp: ${vehiclePosition.timestamp}');
//           print(
//             'Timestamp DateTime: '
//                 '${DateTime.fromMillisecondsSinceEpoch(
//               vehiclePosition.timestamp.toInt() * 1000,
//             )}',
//           );
//         } else {
//           print('Timestamp: N/A');
//         }
//
//         // -------------------------------------------------------
//         // DETERMINE TYPE
//         // -------------------------------------------------------
//         //
//         // Since this API request is specifically:
//         //
//         //     category=rapid-bus-kl
//         //
//         // we treat the returned vehicles as buses.
//         //
//         // Do NOT rely on routeId.startsWith('T') here.
//         //
//         final VehicleType type = VehicleType.bus;
//
//         print('');
//         print('---------------- APP DATA ---------------------');
//         print('Detected Type: ${type.name}');
//
//         final vehicleId = vehiclePosition.hasVehicle()
//             ? vehiclePosition.vehicle.id
//             : entity.id;
//
//         print('App Vehicle ID: $vehicleId');
//         print('App Route ID  : $routeId');
//         print('App Trip ID   : $tripId');
//
//         // -------------------------------------------------------
//         // CREATE VEHICLE OBJECT
//         // -------------------------------------------------------
//         final vehicle = Vehicle(
//           id: vehicleId,
//           routeId: routeId,
//           tripId: tripId,
//           type: type,
//           position: LatLng(
//             position.latitude,
//             position.longitude,
//           ),
//           speed: position.speed,
//           bearing: position.bearing,
//           timestamp: vehiclePosition.hasTimestamp()
//               ? vehiclePosition.timestamp.toInt()
//               : 0,
//         );
//
//         vehicles.add(vehicle);
//
//         print('');
//         print('Vehicle successfully added to app list.');
//       }
//
//       // ---------------------------------------------------------
//       // FINAL RESULT
//       // ---------------------------------------------------------
//       print('');
//       print('');
//       print('============================================================');
//       print('                    FINAL RESULT');
//       print('============================================================');
//
//       print('Entities received : ${feed.entity.length}');
//       print('Vehicles parsed   : ${vehicles.length}');
//
//       print('');
//       print('==================== VEHICLE SUMMARY =======================');
//
//       if (vehicles.isEmpty) {
//         print('NO VALID VEHICLES FOUND.');
//       } else {
//         for (int i = 0; i < vehicles.length; i++) {
//           final vehicle = vehicles[i];
//
//           print('');
//           print('Vehicle #${i + 1}');
//           print('  ID       : ${vehicle.id}');
//           print('  Route    : ${vehicle.routeId}');
//           print('  Trip     : ${vehicle.tripId}');
//           print('  Type     : ${vehicle.type.name}');
//           print('  Latitude : ${vehicle.position.latitude}');
//           print('  Longitude: ${vehicle.position.longitude}');
//           print('  Speed    : ${vehicle.speed}');
//           print('  Bearing  : ${vehicle.bearing}');
//           print('  Timestamp: ${vehicle.timestamp}');
//         }
//       }
//
//       print('');
//       print('============================================================');
//       print('                    END API DEBUG');
//       print('============================================================');
//       print('');
//
//       return vehicles;
//     } catch (e, stackTrace) {
//       print('');
//       print('============================================================');
//       print('                    API ERROR');
//       print('============================================================');
//       print('Error: $e');
//       print('');
//       print('Stack trace:');
//       print(stackTrace);
//       print('============================================================');
//
//       rethrow;
//     }
//   }
// }


import 'package:http/http.dart' as http;
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle.dart';
import 'rapid_socket_api.dart';

class TransportApi {
  static const String _url =
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana'
      '?category=rapid-bus-kl';

  final RapidSocketApi _rapidSocketApi =
  RapidSocketApi();

  Future<List<Vehicle>> fetchVehicles({
    String? fallbackRoute,
  }) async {
    final response = await http.get(
      Uri.parse(_url),
    );

    print('');
    print('========================================');
    print('FETCH');
    print('HTTP status: ${response.statusCode}');
    print(
      'Bytes received: '
          '${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GTFS API request failed: '
            '${response.statusCode}',
      );
    }

    final feed = FeedMessage();

    feed.mergeFromBuffer(
      response.bodyBytes,
    );

    print(
      'Entities received: '
          '${feed.entity.length}',
    );

    print('========================================');

    final List<Vehicle> vehicles = [];

    for (final entity in feed.entity) {
      if (!entity.hasVehicle()) {
        continue;
      }

      final vehiclePosition = entity.vehicle;

      if (!vehiclePosition.hasPosition()) {
        continue;
      }

      final String routeId =
      vehiclePosition.hasTrip()
          ? vehiclePosition.trip.routeId
          : '';

      final String tripId =
      vehiclePosition.hasTrip()
          ? vehiclePosition.trip.tripId
          : '';

      final String vehicleId =
      vehiclePosition.hasVehicle()
          ? vehiclePosition.vehicle.id
          : entity.id;

      final VehicleType type =
      routeId.startsWith('T')
          ? VehicleType.train
          : VehicleType.bus;

      final vehicle = Vehicle(
        id: vehicleId,
        routeId: routeId,
        tripId: tripId,
        type: type,
        position: LatLng(
          vehiclePosition.position.latitude,
          vehiclePosition.position.longitude,
        ),
        speed: vehiclePosition.position.speed,
        bearing: vehiclePosition.position.bearing,
        timestamp:
        vehiclePosition.hasTimestamp()
            ? vehiclePosition.timestamp.toInt()
            : 0,
      );

      vehicles.add(vehicle);

      print(
        '${vehicle.type.name.toUpperCase()} '
            '${vehicle.id} | '
            '${vehicle.routeId} | '
            '${vehicle.position.latitude}, '
            '${vehicle.position.longitude}',
      );
    }

    // GTFS-RT returned vehicles.
    if (vehicles.isNotEmpty) {
      print('Using GTFS-RT data.');

      return vehicles;
    }

    // GTFS-RT returned nothing.
    if (fallbackRoute != null &&
        fallbackRoute.isNotEmpty) {
      print('');
      print(
        'GTFS-RT returned no vehicles.',
      );
      print(
        'Trying RapidKL Socket.IO fallback...',
      );
      print(
        'Route: $fallbackRoute',
      );

      final List<Vehicle> socketVehicles =
      await _rapidSocketApi.fetchVehicles(
        fallbackRoute,
      );

      print(
        'Socket.IO vehicles received: '
            '${socketVehicles.length}',
      );

      return socketVehicles;
    }

    print(
      'No vehicles found and no '
          'Socket.IO fallback route provided.',
    );

    return [];
  }
}