import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/otp_itinerary.dart';

class OtpService {
  // static const String baseUrl =
  //     'http://localhost:8081/otp/gtfs/v1';
  static const String baseUrl =
      'http://10.195.157.132:8081/otp/gtfs/v1';

  Future<List<OtpItinerary>> planJourney({
    required LatLng from,
    required LatLng to,
  }) async {
    const query = r'''
query PlanJourney(
  $dateTime: PlanDateTimeInput
  $origin: PlanLabeledLocationInput!
  $destination: PlanLabeledLocationInput!
  $first: Int
  $modes: PlanModesInput
  $searchWindow: Duration
) {
  planConnection(
    dateTime: $dateTime
    origin: $origin
    destination: $destination
    first: $first
    modes: $modes
    searchWindow: $searchWindow
  ) {
    edges {
      node {
        legs {
          mode
          startTime
          endTime
          duration
          distance

          from {
            name
            lat
            lon
          }

          to {
            name
            lat
            lon
          }

          route {
            gtfsId
            shortName
            longName
          }

          legGeometry {
            length
            points
          }
        }
      }
    }

    routingErrors {
      code
      description
      inputField
    }

    searchDateTime
  }
}
''';

    final now = DateTime.now();
    final offset = now.timeZoneOffset;

    final sign = offset.isNegative ? '-' : '+';
    final hours =
    offset.inHours.abs().toString().padLeft(2, '0');
    final minutes =
    (offset.inMinutes.abs() % 60)
        .toString()
        .padLeft(2, '0');

    final offsetString =
        '$sign$hours:$minutes';

    final dateTime =
        '${now.toIso8601String()}$offsetString';

    final variables = {
      'dateTime': {
        'earliestDeparture': dateTime,
      },
      'origin': {
        'location': {
          'coordinate': {
            'latitude': from.latitude,
            'longitude': from.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'coordinate': {
            'latitude': to.latitude,
            'longitude': to.longitude,
          },
        },
      },
      'first': 5,
      'searchWindow': 'PT12H',
      'modes': {
        'transitOnly': true,
        'transit': {
          'access': ['WALK'],
          'egress': ['WALK'],
          'transfer': ['WALK'],
          'transit': [
            {
              'mode': 'BUS',
            },
          ],
        },
      },
    };

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        'variables': variables,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OTP request failed: '
            '${response.statusCode}',
      );
    }

    final decoded =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (decoded['errors'] != null) {
      throw Exception(
        decoded['errors'].toString(),
      );
    }

    final data =
    decoded['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception(
        'OTP returned no data.',
      );
    }

    final plan =
    data['planConnection'] as Map<String, dynamic>?;

    if (plan == null) {
      throw Exception(
        'OTP returned no plan.',
      );
    }

    final routingErrors =
    plan['routingErrors'] as List<dynamic>?;

    if (routingErrors != null &&
        routingErrors.isNotEmpty) {
      final firstError =
      routingErrors.first as Map<String, dynamic>;

      throw Exception(
        firstError['description'] ??
            'OTP could not find a route.',
      );
    }

    final edges =
        plan['edges'] as List<dynamic>? ?? [];

    return edges.map((edge) {
      final node =
      edge['node'] as Map<String, dynamic>;

      final legs =
          node['legs'] as List<dynamic>? ?? [];

      return OtpItinerary.fromJson(
        legs,
      );
    }).toList();
  }
}