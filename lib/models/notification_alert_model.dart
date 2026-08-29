class NotificationAlertModel {
  final int id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final String type; // 'bus' or 'train'
  final String routeRef; // e.g. '300' or 'Kelana Jaya'
  final String startTime; // '09:00'
  final String endTime; // '11:00'
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
