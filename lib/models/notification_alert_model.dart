/// Represents one row from the "NotificationAlerts" SQLite table — a
/// saved geofence alert like "notify me when bus 300 is near my current
/// location, between 9am and 11am". latitude/longitude are the actual
/// GPS coordinates captured via the "Current Location" button in
/// add_notification_screen.dart — these are what map_screen.dart's
/// geofence check compares the live device position against.
class NotificationAlertModel {
  final int id;
  final String name; // user-facing label, e.g. "Current Location"
  final String location; // display text for the location (not used for math — see lat/lng below)
  final double latitude; // actual GPS latitude used for the geofence distance check
  final double longitude; // actual GPS longitude used for the geofence distance check
  final String type; // 'bus' or 'train' — which Notification Setting screen this belongs to
  final String routeRef; // the saved bus number / train line this alert is for, e.g. '300'
  final String startTime; // active window start, formatted 'HH:MM'
  final String endTime; // active window end, formatted 'HH:MM'
  final String sound;
  final String vibrate;

  NotificationAlertModel({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.routeRef,
    required this.startTime,
    required this.endTime,
    required this.sound,
    required this.vibrate,
  });

  // Builds a NotificationAlertModel from a raw database row. The
  // latitude/longitude type check handles SQLite sometimes returning
  // whole-number coordinates as int instead of double.
  factory NotificationAlertModel.fromJson(Map<String, dynamic> data) =>
      NotificationAlertModel(
        id: data['id'],
        name: data['name'],
        location: data['location'],
        latitude: data['latitude'] is int
            ? (data['latitude'] as int).toDouble()
            : data['latitude'],
        longitude: data['longitude'] is int
            ? (data['longitude'] as int).toDouble()
            : data['longitude'],
        type: data['type'],
        routeRef: data['routeRef'],
        startTime: data['startTime'],
        endTime: data['endTime'],
        sound: data['sound'],
        vibrate: data['vibrate'],
      );

  // Converts this object back into a Map for db.insert().
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'routeRef': routeRef,
        'startTime': startTime,
        'endTime': endTime,
        'sound': sound,
        'vibrate': vibrate,
      };
}
