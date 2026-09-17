import 'package:latlong2/latlong.dart';

class OtpItinerary {
  final List<OtpLeg> legs;

  OtpItinerary({
    required this.legs,
  });

  factory OtpItinerary.fromJson(
      List<dynamic> json,
      ) {
    return OtpItinerary(
      legs: json
          .map(
            (leg) => OtpLeg.fromJson(
          leg as Map<String, dynamic>,
        ),
      )
          .toList(),
    );
  }

  int get totalDuration {
    return legs.fold(
      0,
          (total, leg) => total + leg.duration,
    );
  }

  bool get containsTransit {
    return legs.any(
          (leg) => leg.isTransit,
    );
  }
}

class OtpLeg {
  final String mode;

  final int startTime;
  final int endTime;
  final int duration;

  final double distance;

  final String fromName;
  final double fromLat;
  final double fromLon;

  final String toName;
  final double toLat;
  final double toLon;

  final String? routeId;
  final String? routeShortName;
  final String? routeLongName;

  final String? geometry;

  OtpLeg({
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distance,
    required this.fromName,
    required this.fromLat,
    required this.fromLon,
    required this.toName,
    required this.toLat,
    required this.toLon,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.geometry,
  });

  factory OtpLeg.fromJson(
      Map<String, dynamic> json,
      ) {
    final from =
    json['from'] as Map<String, dynamic>;

    final to =
    json['to'] as Map<String, dynamic>;

    final route =
    json['route'] as Map<String, dynamic>?;

    final legGeometry =
    json['legGeometry'] as Map<String, dynamic>?;

    return OtpLeg(
      mode: json['mode'] ?? '',

      startTime:
      (json['startTime'] ?? 0).toInt(),

      endTime:
      (json['endTime'] ?? 0).toInt(),

      duration:
      (json['duration'] ?? 0).toInt(),

      distance:
      (json['distance'] ?? 0).toDouble(),

      fromName:
      from['name'] ?? '',

      fromLat:
      (from['lat'] ?? 0).toDouble(),

      fromLon:
      (from['lon'] ?? 0).toDouble(),

      toName:
      to['name'] ?? '',

      toLat:
      (to['lat'] ?? 0).toDouble(),

      toLon:
      (to['lon'] ?? 0).toDouble(),

      routeId:
      route?['gtfsId'],

      routeShortName:
      route?['shortName'],

      routeLongName:
      route?['longName'],

      geometry:
      legGeometry?['points'],
    );
  }

  bool get isTransit {
    return mode != 'WALK';
  }

  String get displayMode {
    switch (mode) {
      case 'WALK':
        return 'Walk';

      case 'BUS':
        return 'Bus';

      case 'RAIL':
        return 'Rail';

      case 'SUBWAY':
        return 'Train';

      case 'TRAM':
        return 'Tram';

      default:
        return mode;
    }
  }

  String get modeIcon {
    switch (mode) {
      case 'WALK':
        return '🚶';

      case 'BUS':
        return '🚌';

      case 'RAIL':
      case 'SUBWAY':
      case 'TRAM':
        return '🚆';

      default:
        return '🚏';
    }
  }

  String get durationText {
    final minutes =
    (duration / 60).round();

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours =
        minutes ~/ 60;

    final remaining =
        minutes % 60;

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  LatLng get fromLocation {
    return LatLng(
      fromLat,
      fromLon,
    );
  }

  LatLng get toLocation {
    return LatLng(
      toLat,
      toLon,
    );
  }
}