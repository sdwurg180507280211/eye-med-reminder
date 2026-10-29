import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class ReminderNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  String? launchKey;
  bool ready = false;
  bool? permissionGranted;
  int scheduledCount = 0;
  DateTime? scheduledUntil;
  bool exact = false;
  bool exactRequested = false;
  Future<void> _tail = Future.value();
  Future<void> _refreshTimezone() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  }

  void _resetScheduleState() {
    scheduledUntil = null;
    scheduledCount = 0;
    exact = false;
  }

  Future<void> initialize(void Function(String) open) async {
    tzdata.initializeTimeZones();
    await _refreshTimezone();
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

  Future<bool> schedule(Patient patient, {bool requestPermission = false}) {
    final result = _tail.then(
      (_) => _schedule(patient, requestPermission: requestPermission),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _schedule(
    Patient patient, {
    required bool requestPermission,
  }) async {
    _resetScheduleState();
    permissionGranted = null;
    if (!ready) {
      return false;
    }
    try {
      // Clear the previous profile's reminders before replacing the queue.
      await plugin.cancelAll();
      await _refreshTimezone();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        permissionGranted = requestPermission
            ? await android.requestNotificationsPermission() ?? false
            : await android.areNotificationsEnabled() ?? false;
      } else if (ios != null) {
        permissionGranted = requestPermission
            ? await ios.requestPermissions(
                    alert: true,
                    badge: true,
                    sound: true,
                  ) ??
                  false
            : (await ios.checkPermissions())?.isEnabled ?? false;
      } else {
        permissionGranted = false;
      }
      if (!permissionGranted!) {
        return false;
      }
      exact =
          android == null ||
          (await android.canScheduleExactNotifications() ?? false);
      if (android != null && !exact && requestPermission) {
        exactRequested = true;
        exact = await android.requestExactAlarmsPermission() ?? false;
      }
      var id = 0;
      final events = upcoming(patient, DateTime.now());
      for (final event in events) {
        // The prescription time follows the device's current local clock.
        final at = event.at;
        await plugin.zonedSchedule(
          id++,
          '${patient.name}，${event.title}',
          event.body,
          tz.TZDateTime(
            tz.local,
            at.year,
            at.month,
            at.day,
            at.hour,
            at.minute,
          ),
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
      scheduledCount = events.length;
      scheduledUntil = events.isEmpty ? null : events.last.at;
      return true;
    } catch (_) {
      _resetScheduleState();
      // A failed replacement must not leave a partial reminder queue active.
      try {
        await plugin.cancelAll();
      } catch (_) {
        // Preserve the original scheduling error for the caller.
      }
      rethrow;
    }
  }

  Future<void> cancel() {
    final result = _tail.then((_) async {
      try {
        if (ready) {
          await plugin.cancelAll();
        }
      } finally {
        _resetScheduleState();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
