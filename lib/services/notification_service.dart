// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final windowsSettings = WindowsInitializationSettings(
      appName: 'Transport Tracker',
      appUserModelId: 'Com.TransportTracker.App',
      guid: '92517ef0-7d73-4894-bcab-f356dce4a5e1', // just needs to be unique to your app
    );
    final initSettings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings, // NEW
    );
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  Future<void> showAlert({required int id, required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'transport_alerts',
      'Transport Alerts',
      channelDescription: 'Notifies you when your bus/train is near your saved location',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: id,                      // CHANGED: named
      title: title,                // CHANGED: named
      body: body,                  // CHANGED: named
      notificationDetails: details, // CHANGED: named, and renamed from "details"
    );
  }
}