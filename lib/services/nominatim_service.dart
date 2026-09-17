import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimService {
  static const String _baseUrl =
      'https://nominatim.openstreetmap.org/search';

  DateTime? _lastRequestTime;

  Future<void> _waitForRateLimit() async {
    final lastRequest = _lastRequestTime;

    if (lastRequest != null) {
      final elapsed =
      DateTime.now().difference(lastRequest);

      const minimumDelay =
      Duration(seconds: 1);

      if (elapsed < minimumDelay) {
        await Future.delayed(
          minimumDelay - elapsed,
        );
      }
    }

    _lastRequestTime = DateTime.now();
  }

  Future<List<NominatimResult>> search(
      String query,
      ) async {
    if (query.trim().isEmpty) {
      return [];
    }

    // Nominatim's public service requires
    // no more than 1 request per second.
    await _waitForRateLimit();

    final uri = Uri.parse(
      _baseUrl,
    ).replace(
      queryParameters: {
        'q': query.trim(),
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'my',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
        'TransportTracker/1.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Nominatim request failed: '
            '${response.statusCode}',
      );
    }

    final List<dynamic> data =
    jsonDecode(response.body);

    return data.map((item) {
      return NominatimResult(
        displayName:
        item['display_name'] ?? '',
        location: LatLng(
          double.parse(item['lat']),
          double.parse(item['lon']),
        ),
      );
    }).toList();
  }
}

class NominatimResult {
  final String displayName;
  final LatLng location;

  NominatimResult({
    required this.displayName,
    required this.location,
  });
}