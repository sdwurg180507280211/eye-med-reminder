import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_med_reminder/models.dart';
import 'package:eye_med_reminder/notifications.dart';

Patient notificationPatient() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return Patient(
    id: 'patient',
    name: '王',
    salt: '',
    hash: '',
    plans: [
      Plan(
        id: 'plan',
        created: tomorrow,
        medications: [
          Medication(
            id: 'med',
            name: '人工泪液',
            eye: '双眼',
            dose: '1滴',
            frequency: '每日2次',
            start: tomorrow,
            days: 1,
            times: ['08:00', '12:00'],
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const zoneChannel = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late String zone;
  late bool granted;
  late bool failSchedule;
  Future<Object?> handler(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'initialize':
        return true;
      case 'getNotificationAppLaunchDetails':
        return {'notificationLaunchedApp': false};
      case 'checkPermissions':
        return {
          'isEnabled': granted,
          'isAlertEnabled': granted,
          'isSoundEnabled': granted,
        };
      case 'requestPermissions':
      case 'requestNotificationsPermission':
      case 'areNotificationsEnabled':
        return granted;
      case 'canScheduleExactNotifications':
      case 'requestExactAlarmsPermission':
        return false;
      case 'zonedSchedule':
        if (failSchedule) {
          throw PlatformException(code: 'schedule_failed');
        }
    }
    return null;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    zone = 'Asia/Taipei';
    granted = true;
    failSchedule = false;
    messenger.setMockMethodCallHandler(channel, handler);
    messenger.setMockMethodCallHandler(zoneChannel, (_) async => zone);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(zoneChannel, null);
  });

  test(
    'passive refresh checks permission without prompting and tracks queue',
    () async {
      final notifications = ReminderNotifications();
      await notifications.initialize((_) {});
      expect(await notifications.schedule(notificationPatient()), isTrue);
      expect(notifications.permissionGranted, isTrue);
      expect(notifications.scheduledCount, 2);
      expect(notifications.scheduledUntil, isNotNull);
      expect(calls.where((c) => c.method == 'checkPermissions'), hasLength(1));
      expect(calls.where((c) => c.method == 'requestPermissions'), isEmpty);
      expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(2));
      await notifications.cancel();
      expect(notifications.scheduledCount, 0);
      expect(notifications.scheduledUntil, isNull);
    },
  );

  test('explicit permission denial clears prior scheduling status', () async {
    final notifications = ReminderNotifications();
    await notifications.initialize((_) {});
    final patient = notificationPatient();
    await notifications.schedule(patient);
    granted = false;
    calls.clear();
    expect(
      await notifications.schedule(patient, requestPermission: true),
      isFalse,
    );
    expect(notifications.permissionGranted, isFalse);
    expect(notifications.scheduledCount, 0);
    expect(notifications.scheduledUntil, isNull);
    expect(calls.where((c) => c.method == 'requestPermissions'), hasLength(1));
    expect(calls.where((c) => c.method == 'cancelAll'), hasLength(1));
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
  });

  test(
    'device timezone changes are reflected without shifting prescription clock',
    () async {
      final notifications = ReminderNotifications();
      await notifications.initialize((_) {});
      final patient = notificationPatient();
      await notifications.schedule(patient);
      var queued =
          calls.firstWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(queued['timeZoneName'], 'Asia/Taipei');
      expect(queued['scheduledDateTime'], contains('T08:00:00'));
      calls.clear();
      zone = 'America/Los_Angeles';
      await notifications.schedule(patient);
      queued =
          calls.firstWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(queued['timeZoneName'], 'America/Los_Angeles');
      expect(queued['scheduledDateTime'], contains('T08:00:00'));
      expect(queued['payload'], startsWith('patient#plan|med|'));
    },
  );

  test(
    'paused and completed doses are excluded from native scheduling',
    () async {
      final notifications = ReminderNotifications();
      await notifications.initialize((_) {});
      final patient = notificationPatient();
      final plan = patient.plans.single;
      final event = eventsFor(plan, plan.medications.single.start).first;
      patient.doseCompletions[event.occurrenceKey] = DateTime.now();
      await notifications.schedule(patient);
      expect(notifications.scheduledCount, 1);
      plan.remindersPaused = true;
      calls.clear();
      expect(await notifications.schedule(patient), isTrue);
      expect(notifications.scheduledCount, 0);
      expect(notifications.scheduledUntil, isNull);
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    },
  );

  test(
    'failure cancels partial scheduling and does not poison the next refresh',
    () async {
      final notifications = ReminderNotifications();
      await notifications.initialize((_) {});
      final patient = notificationPatient();
      failSchedule = true;
      await expectLater(
        notifications.schedule(patient),
        throwsA(isA<PlatformException>()),
      );
      expect(notifications.scheduledCount, 0);
      expect(notifications.scheduledUntil, isNull);
      expect(calls.where((c) => c.method == 'cancelAll'), hasLength(2));
      failSchedule = false;
      expect(await notifications.schedule(patient), isTrue);
      expect(notifications.scheduledCount, 2);
    },
  );

  test(
    'cancel waits for an in-flight schedule before clearing reminders',
    () async {
      final notifications = ReminderNotifications();
      await notifications.initialize((_) {});
      final entered = Completer<void>();
      final release = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'zonedSchedule' && !entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        return handler(call);
      });
      final scheduled = notifications.schedule(notificationPatient());
      await entered.future;
      final cancelled = notifications.cancel();
      release.complete();
      await scheduled;
      await cancelled;
      expect(calls.last.method, 'cancelAll');
      expect(notifications.scheduledCount, 0);
      expect(notifications.scheduledUntil, isNull);
    },
  );

  test(
    'Android background refresh avoids permission and exact-alarm dialogs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final notifications = ReminderNotifications();
      await notifications.initialize((_) {});
      final patient = notificationPatient();
      expect(await notifications.schedule(patient), isTrue);
      expect(notifications.exact, isFalse);
      expect(
        calls.where((c) => c.method == 'areNotificationsEnabled'),
        hasLength(1),
      );
      expect(
        calls.where((c) => c.method == 'requestNotificationsPermission'),
        isEmpty,
      );
      expect(
        calls.where((c) => c.method == 'requestExactAlarmsPermission'),
        isEmpty,
      );
      await notifications.schedule(patient, requestPermission: true);
      expect(
        calls.where((c) => c.method == 'requestNotificationsPermission'),
        hasLength(1),
      );
      expect(
        calls.where((c) => c.method == 'requestExactAlarmsPermission'),
        hasLength(1),
      );
    },
  );
}
