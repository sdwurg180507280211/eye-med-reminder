import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class ReminderNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  String? launchKey;
  bool ready = false;
  DateTime? scheduledUntil;
  bool exact = false;
  Future<void> _tail = Future.value();
  Future<void> initialize(void Function(String) open) async {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) {
          open(r.payload!);
        }
      },
    );
    launchKey = (await plugin.getNotificationAppLaunchDetails())
        ?.notificationResponse
        ?.payload;
    ready = true;
  }

  Future<bool> schedule(Patient patient) {
    final result = _tail.then((_) => _schedule(patient));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _schedule(Patient patient) async {
    if (!ready) {
      return false;
    }
    scheduledUntil = null;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    await plugin.cancelAll();
    if (!granted) {
      return false;
    }
    exact =
        android == null ||
        (await android.canScheduleExactNotifications() ?? false);
    if (android != null && !exact) {
      exact = await android.requestExactAlarmsPermission() ?? false;
    }
    var id = 0;
    final events = upcoming(patient, DateTime.now());
    for (final event in events) {
      await plugin.zonedSchedule(
        id++,
        '${patient.name}，${event.title}',
        event.body,
        tz.TZDateTime.from(event.at, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'eye_med_v1',
            '用药与复查提醒',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${patient.id}#${event.key}',
      );
    }
    scheduledUntil = events.isEmpty ? null : events.last.at;
    return true;
  }

  Future<void> cancel() {
    final result = _tail.then((_) async {
      if (ready) {
        await plugin.cancelAll();
      }
      scheduledUntil = null;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
