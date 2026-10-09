import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifications locales : prévient le joueur d'une panne pendant son absence.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _breakdownId = 1;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (error) {
      debugPrint('Notifications indisponibles : $error');
    }
  }

  Future<void> scheduleBreakdown({
    required String equipmentName,
    required Duration delay,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      await _plugin.zonedSchedule(
        id: _breakdownId,
        scheduledDate: tz.TZDateTime.now(tz.UTC).add(delay),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'pannes',
            'Pannes',
            channelDescription: 'Alertes de panne pendant votre absence',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Risque de panne',
        body: '$equipmentName arrive en fin de vie. Votre équipe vous attend.',
      );
    } catch (error) {
      debugPrint('Planification impossible : $error');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Annulation impossible : $error');
    }
  }
}
