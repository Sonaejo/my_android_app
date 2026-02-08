// lib/services/reminder_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(initSettings);

    // Android 13+ 通知権限
    final perm = await Permission.notification.request();
    debugPrint("[ReminderService] Notification permission: $perm");

    _initialized = true;
  }

  /// Android 12+ 正確なアラーム権限
  static Future<void> _requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  /// ────────────────────────────────
  /// ★ 毎日決まった時間の通知
  /// ────────────────────────────────
  static Future<void> updateDailyReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    await init();

    const id = 1;

    if (!enabled) {
      await _plugin.cancel(id);
      debugPrint("[ReminderService] Daily reminder canceled");
      return;
    }

    await _requestExactAlarmPermission();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    debugPrint("[ReminderService] Schedule daily: $scheduled");

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'トレーニングリマインダー',
      channelDescription: '毎日のトレーニング時間通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      'トレーニングの時間です',
      'そろそろ今日のトレーニングを始めましょう！',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
