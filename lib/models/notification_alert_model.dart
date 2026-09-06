
class NotificationAlertModel {
  final int id;
  final String routeRef;
  final String sound;
  final String vibrate;

  NotificationAlertModel({
    required this.id,
    required this.routeRef,
    required this.sound,
    required this.vibrate,
  });

  factory NotificationAlertModel.fromJson(Map<String, dynamic> data) =>
      NotificationAlertModel(
        id: data['id'],
        routeRef: data['routeRef'],
        sound: data['sound'],
        vibrate: data['vibrate'],
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'routeRef': routeRef,
    'sound': sound,
    'vibrate': vibrate,
      };
}
