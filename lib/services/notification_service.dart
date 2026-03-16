import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    if (!kIsWeb) {
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification click if needed
          debugPrint("Notification clicked: ${details.payload}");
        },
      );
    }

    _isInitialized = true;
    debugPrint("[NotificationService] Initialized");
  }

  Future<void> showHighPpmAlert(double ppm) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ppm_alerts',
      'PPM Safety Alerts',
      channelDescription: 'Alerts when formaldehyde levels exceed safety thresholds.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Formaldehyde Alert',
      color: Colors.red,
      ledColor: Colors.red,
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (!kIsWeb) {
      await _localNotifications.show(
        0,
        '⚠️ HIGH FORMALDEHYDE ALERT',
        'Level detected: ${ppm.toStringAsFixed(3)} PPM. Open a window immediately!',
        platformDetails,
        payload: 'high_ppm_alert',
      );
    }
  }
}
