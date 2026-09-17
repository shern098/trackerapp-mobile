import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/vehicle.dart';

class RapidSocketApi {
  static const String _url =
      'https://rapidbus-socketio-avl.prasarana.com.my';

  Future<List<Vehicle>> fetchVehicles(String routeId) async {
    final completer = Completer<List<Vehicle>>();

    late IO.Socket socket;

    socket = IO.io(
      _url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    void finish(List<Vehicle> vehicles) {
      if (!completer.isCompleted) {
        completer.complete(vehicles);
      }

      socket.disconnect();
      socket.dispose();
    }

    socket.onConnect((_) {
      print('');
      print('========================================');
      print('SOCKET.IO');
      print('Connected');
      print('Route: $routeId');
      print('========================================');

      final payload = {
        'sid': '',
        'uid': '',
        'provider': 'RKL',
        'route': routeId,
      };

      socket.emit('onFts-reload', payload);
    });

    socket.on('onFts-client', (data) {
      try {
        print('Socket.IO data received');

        final String encodedData = data.toString();

        final Uint8List compressed = base64Decode(encodedData);

        final List<int> decompressed =
        GZipCodec().decode(compressed);

        final dynamic decoded =
        jsonDecode(utf8.decode(decompressed));

        final List<dynamic> busData;

        if (decoded is List) {
          busData = decoded;
        } else if (decoded is Map) {
          busData = [decoded];
        } else {
          throw Exception(
            'Unexpected Socket.IO data format',
          );
        }

        final List<Vehicle> vehicles = [];

        for (final item in busData) {
          if (item is! Map) {
            continue;
          }

          final String busId =
              item['bus_no']?.toString() ?? '';

          final String tripId =
              item['trip_no']?.toString() ?? '';

          final String receivedRoute =
              item['route']?.toString() ?? routeId;

          final double latitude =
              double.tryParse(
                item['latitude']?.toString() ?? '',
              ) ??
                  0.0;

          final double longitude =
              double.tryParse(
                item['longitude']?.toString() ?? '',
              ) ??
                  0.0;

          final double speed =
              double.tryParse(
                item['speed']?.toString() ?? '',
              ) ??
                  0.0;

          final double bearing =
              double.tryParse(
                item['angle']?.toString() ?? '',
              ) ??
                  0.0;

          int timestamp = 0;

          final String? gpsTime =
          item['dt_gps']?.toString();

          if (gpsTime != null && gpsTime.isNotEmpty) {
            final DateTime? parsedTime =
            DateTime.tryParse(gpsTime);

            if (parsedTime != null) {
              timestamp =
                  parsedTime.millisecondsSinceEpoch ~/ 1000;
            }
          }

          final vehicle = Vehicle(
            id: busId,
            routeId: receivedRoute,
            tripId: tripId,
            type: VehicleType.bus,
            position: LatLng(
              latitude,
              longitude,
            ),
            speed: speed,
            bearing: bearing,
            timestamp: timestamp,
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

        finish(vehicles);
      } catch (e) {
        print('Socket.IO decode error: $e');

        finish([]);
      }
    });

    socket.onConnectError((error) {
      print('Socket.IO connection error: $error');

      finish([]);
    });

    socket.onError((error) {
      print('Socket.IO error: $error');

      finish([]);
    });

    socket.onDisconnect((_) {
      print('Socket.IO disconnected');
    });

    socket.connect();

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        print('Socket.IO request timed out');

        if (socket.connected) {
          socket.disconnect();
          socket.dispose();
        }

        return <Vehicle>[];
      },
    );
  }
}