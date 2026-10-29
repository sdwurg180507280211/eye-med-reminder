import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_med_reminder/design_system.dart';
import 'package:eye_med_reminder/main.dart';
import 'package:eye_med_reminder/models.dart';
import 'package:eye_med_reminder/notifications.dart';
import 'package:eye_med_reminder/storage.dart';

final testNow = DateTime(2026, 10, 4, 9);

class HomeStore extends PatientStore {
  HomeStore(Patient patient, {super.storage}) {
    patients = [patient];
  }

  @override
  Future<void> load() async {}

  @override
  Future<Patient?> login(String name, String pin) async {
    for (final patient in patients) {
      if (patient.name == name && pin == '123456') return patient;
    }
    return null;
  }
}

class FailingHomeStorage extends FlutterSecureStorage {
  bool failNextWrite = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw PlatformException(code: 'storage_write_failed');
    }
    await super.write(key: key, value: value);
  }
}

class HomeNotifications extends ReminderNotifications {
  late void Function(String) open;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  bool cancelStarted = false;
  final permissionRequests = <bool>[];
  Completer<void>? cancelGate;

  @override
  Future<void> initialize(void Function(String) open) async {
    this.open = open;
    ready = true;
    exact = true;
    permissionGranted = true;
  }

  @override
  Future<bool> schedule(
    Patient patient, {
    bool requestPermission = false,
  }) async {
    scheduleCalls++;
    permissionRequests.add(requestPermission);
    final events = upcoming(patient, testNow);
    scheduledCount = events.length;
    scheduledUntil = events.isEmpty ? null : events.last.at;
    return true;
  }

  @override
  Future<void> cancel() async {
    cancelStarted = true;
    if (cancelGate != null) await cancelGate!.future;
    cancelCalls++;
    scheduledCount = 0;
    scheduledUntil = null;
  }

  void emit(Patient patient, ReminderEvent event) =>
      open('${patient.id}#${event.key}');
}

class RetryingHomeNotifications extends HomeNotifications {
  int initializeCalls = 0;
  final initializeGate = Completer<void>();

  @override
  Future<void> initialize(void Function(String) open) async {
    initializeCalls++;
    if (initializeCalls == 1) {
      throw PlatformException(code: 'initialization_failed');
    }
    await initializeGate.future;
    await super.initialize(open);
  }
}

Plan homePlan({String id = 'plan', bool paused = false, String? name}) => Plan(
  id: id,
  created: day(testNow),
  remindersPaused: paused,
  medications: [
    Medication(
      id: 'med-$id',
      name: name ?? '人工泪液',
      eye: '双眼',
      dose: '每眼1滴',
      frequency: '每日2次',
      start: day(testNow),
      days: 1,
      times: ['08:00', '12:00'],
    ),
  ],
);

Patient homePatient({List<Plan>? plans}) => Patient(
  id: 'patient',
  name: '张建国',
  salt: '',
  hash: '',
  plans: plans ?? [homePlan()],
);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder dialogAction(String label) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(FilledButton, label),
);

Finder dueRecordButton(Patient patient) {
  final dose = eventsFor(patient.plans.first, testNow).first;
  return find.descendant(
    of: find.byKey(ValueKey('dose-${dose.occurrenceKey}')),
    matching: find.text('记录已用药'),
  );
}

Future<void> selectTab(WidgetTester tester, String label) => tapVisible(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Future<void> signInHome(
  WidgetTester tester,
  HomeStore store,
  HomeNotifications notifications, {
  Size size = const Size(430, 932),
  double textScale = 1,
  DateTime? currentTime,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(null);
  });
  await store.save();
  await tester.pumpWidget(
    MaterialApp(
      theme: eyeMedTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PatientHome(
        store: store,
        notifications: notifications,
        now: () => currentTime ?? testNow,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await reveal(tester, find.byKey(const ValueKey('patient-name')));
  await tester.enterText(find.byKey(const ValueKey('patient-name')), '张建国');
  await reveal(tester, find.byKey(const ValueKey('login-pin')));
  await tester.enterText(find.byKey(const ValueKey('login-pin')), '123456');
  await tapVisible(tester, find.text('进入我的档案'));
  expect(notifications.permissionRequests, [true]);
}

Future<Patient> persistedPatient() async {
  final raw = await const FlutterSecureStorage().read(key: 'patients_v1');
  return Patient.decode(raw!).single;
}

Medication midnightMedication(String id, DateTime start, String time) =>
    Medication(
      id: id,
      name: '药$id',
      eye: '双眼',
      dose: '1滴',
      frequency: '每日1次',
      start: start,
      days: 1,
      times: [time],
    );

Future<void> expectMidnightConflict(
  WidgetTester tester, {
  required List<Medication> existing,
  required Medication draft,
  DateTime? currentTime,
}) async {
  final patient = homePatient(
    plans: [Plan(id: 'existing', created: testNow, medications: existing)],
  );
  await signInHome(
    tester,
    HomeStore(patient),
    HomeNotifications(),
    currentTime: currentTime,
  );
  await selectTab(tester, '添加处方');
  await tapVisible(tester, find.text('手动添加药物'));
  // Return a complete editor result to exercise the real confirmation flow.
  tester.state<NavigatorState>(find.byType(Navigator).first).pop(draft);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('确认并开启提醒'));
  expect(find.text('有实际提醒时间重叠'), findsOneWidget);
  expect(find.textContaining('2026-10-05 00:05：'), findsOneWidget);
  expect(patient.plans, hasLength(1));
  await tapVisible(tester, find.text('取消'));
  expect((await persistedPatient()).plans, hasLength(1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    messenger.setMockMethodCallHandler(ttsChannel, (_) async => 1);
  });
  tearDown(() => messenger.setMockMethodCallHandler(ttsChannel, null));

  testWidgets(
    'today recording requires confirmation, persists and can be undone',
    (tester) async {
      final patient = homePatient();
      final store = HomeStore(patient);
      final notifications = HomeNotifications();
      final dose = eventsFor(patient.plans.single, testNow).first;
      await signInHome(tester, store, notifications);
      await tapVisible(tester, dueRecordButton(patient));
      expect(find.text('确认已用药？'), findsOneWidget);
      expect(patient.doseCompletions, isEmpty);
      await tapVisible(tester, dialogAction('确认记录'));
      expect(patient.doseCompletions[dose.occurrenceKey], testNow);
      expect((await persistedPatient()).isCompleted(dose), isTrue);
      await reveal(tester, find.text('共 2 次 · 已记录 1 次'));
      expect(find.text('共 2 次 · 已记录 1 次'), findsOneWidget);
      expect(notifications.permissionRequests, [true, false]);
      await tapVisible(tester, find.text('撤销记录'));
      await tapVisible(tester, dialogAction('撤销记录'));
      expect(patient.doseCompletions, isEmpty);
      expect((await persistedPatient()).doseCompletions, isEmpty);
    },
  );

  testWidgets('failed completion write restores UI and durable record', (
    tester,
  ) async {
    final patient = homePatient();
    final storage = FailingHomeStorage();
    final store = HomeStore(patient, storage: storage);
    final notifications = HomeNotifications();
    await signInHome(tester, store, notifications);
    storage.failNextWrite = true;
    await tapVisible(tester, dueRecordButton(patient));
    await tapVisible(tester, dialogAction('确认记录'));
    expect(patient.doseCompletions, isEmpty);
    expect((await persistedPatient()).doseCompletions, isEmpty);
    expect(find.text('记录保存失败，请重试。'), findsOneWidget);
    expect(find.text('撤销记录'), findsNothing);
    expect(notifications.scheduleCalls, 1);
  });

  testWidgets(
    'plan pause and resume retain history and refresh native reminders',
    (tester) async {
      final patient = homePatient();
      final plan = patient.plans.single;
      final dose = eventsFor(plan, testNow).first;
      patient.doseCompletions[dose.occurrenceKey] = DateTime(2026, 10, 4, 8, 5);
      final store = HomeStore(patient);
      final notifications = HomeNotifications();
      await signInHome(tester, store, notifications);
      await selectTab(tester, '用药计划');
      await tapVisible(tester, find.text('暂停提醒'));
      await tapVisible(tester, dialogAction('暂停提醒'));
      expect(plan.remindersPaused, isTrue);
      expect(patient.isCompleted(dose), isTrue);
      expect(notifications.scheduledCount, 0);
      expect((await persistedPatient()).plans.single.remindersPaused, isTrue);
      await tapVisible(tester, find.text('恢复提醒'));
      await tapVisible(tester, dialogAction('恢复提醒'));
      expect(plan.remindersPaused, isFalse);
      expect(patient.isCompleted(dose), isTrue);
      expect(notifications.scheduledCount, 1);
      expect(
        (await persistedPatient()).doseCompletions,
        patient.doseCompletions,
      );
      expect(notifications.permissionRequests, [true, false, false]);
    },
  );

  testWidgets(
    'resuming a duplicate overlapping plan is blocked before saving',
    (tester) async {
      final active = homePlan(id: 'active');
      final paused = homePlan(id: 'paused', paused: true);
      final patient = homePatient(plans: [active, paused]);
      final store = HomeStore(patient);
      final notifications = HomeNotifications();
      await signInHome(tester, store, notifications);
      await selectTab(tester, '用药计划');
      await tapVisible(tester, find.text('恢复提醒'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('已有相同药物在重叠疗程、眼别和时间提醒。请先核对其他计划，再恢复这份计划。'),
        findsOneWidget,
      );
      expect(paused.remindersPaused, isTrue);
      expect((await persistedPatient()).plans.last.remindersPaused, isTrue);
      expect(notifications.scheduleCalls, 1);
    },
  );

  testWidgets(
    'lifecycle resume cannot reschedule while logout cancellation is pending',
    (tester) async {
      final patient = homePatient();
      final store = HomeStore(patient);
      final notifications = HomeNotifications();
      await signInHome(tester, store, notifications);
      notifications.cancelGate = Completer<void>();
      await tapVisible(tester, find.byTooltip('退出患者档案'));
      await tapVisible(tester, dialogAction('退出'));
      expect(notifications.cancelStarted, isTrue);
      final schedulesBefore = notifications.scheduleCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(notifications.scheduleCalls, schedulesBefore);
      notifications.cancelGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('patient-name')), findsOneWidget);
      expect(notifications.cancelCalls, 1);
      expect(notifications.scheduledCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(notifications.scheduleCalls, schedulesBefore);
    },
  );

  testWidgets(
    'initialization retry cannot schedule a patient who signed out meanwhile',
    (tester) async {
      final patient = homePatient();
      final store = HomeStore(patient);
      final notifications = RetryingHomeNotifications();
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: eyeMedTheme(),
          home: PatientHome(
            store: store,
            notifications: notifications,
            now: () => testNow,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(notifications.initializeCalls, 1);
      await reveal(tester, find.byKey(const ValueKey('patient-name')));
      await tester.enterText(find.byKey(const ValueKey('patient-name')), '张建国');
      await reveal(tester, find.byKey(const ValueKey('login-pin')));
      await tester.enterText(find.byKey(const ValueKey('login-pin')), '123456');
      await reveal(tester, find.text('进入我的档案'));
      await tester.tap(find.text('进入我的档案'));
      await tester.pump();
      expect(notifications.initializeCalls, 2);
      expect(notifications.ready, isFalse);
      // The pending initialization keeps the notification spinner active.
      await tester.tap(find.byTooltip('退出患者档案'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(dialogAction('退出'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(notifications.cancelCalls, 1);
      expect(find.byKey(const ValueKey('patient-name')), findsOneWidget);
      notifications.initializeGate.complete();
      await tester.pumpAndSettle();
      expect(notifications.ready, isTrue);
      expect(notifications.scheduleCalls, 0);
      expect(notifications.scheduledCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('draft morning dose warns about prior-day staggered medicine', (
    tester,
  ) async {
    await expectMidnightConflict(
      tester,
      existing: [
        midnightMedication('A', DateTime(2026, 10, 4), '23:55'),
        midnightMedication('B', DateTime(2026, 10, 4), '23:55'),
      ],
      draft: midnightMedication('C', DateTime(2026, 10, 5), '00:05'),
    );
  });

  testWidgets('draft late dose warns about next-day original-time medicine', (
    tester,
  ) async {
    await expectMidnightConflict(
      tester,
      existing: [
        midnightMedication('A', DateTime(2026, 10, 4), '23:55'),
        midnightMedication('C', DateTime(2026, 10, 5), '00:05'),
      ],
      draft: midnightMedication('B', DateTime(2026, 10, 4), '23:55'),
    );
  });

  testWidgets('after midnight yesterday draft still warns about future dose', (
    tester,
  ) async {
    await expectMidnightConflict(
      tester,
      existing: [
        midnightMedication('A', DateTime(2026, 10, 4), '23:55'),
        midnightMedication('C', DateTime(2026, 10, 5), '00:05'),
      ],
      draft: midnightMedication('B', DateTime(2026, 10, 4), '23:55'),
      currentTime: DateTime(2026, 10, 5, 0, 1),
    );
  });

  testWidgets(
    'notification over a dirty medication editor returns to its entered text',
    (tester) async {
      final patient = homePatient();
      final store = HomeStore(patient);
      final notifications = HomeNotifications();
      await signInHome(tester, store, notifications);
      await selectTab(tester, '添加处方');
      await tapVisible(tester, find.text('手动添加药物'));
      final field = find.byKey(const ValueKey('medication-name'));
      await tester.enterText(field, '尚未确认的新药');
      notifications.emit(
        patient,
        eventsFor(patient.plans.single, testNow).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReminderPage), findsOneWidget);
      await tapVisible(tester, find.text('结束提醒'));
      expect(find.byType(MedicationEditor), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, '尚未确认的新药');
      expect(find.byType(AlertDialog), findsNothing);
      expect(patient.doseCompletions, isEmpty);
    },
  );

  testWidgets(
    'small screen and large text keep home, plans and confirmation usable',
    (tester) async {
      final patient = homePatient(
        plans: [homePlan(name: '玻璃酸钠滴眼液（不含防腐剂，请核对处方上的完整药名）')],
      );
      final store = HomeStore(patient);
      final notifications = HomeNotifications();
      await signInHome(
        tester,
        store,
        notifications,
        size: const Size(320, 700),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tapVisible(tester, dueRecordButton(patient));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, dialogAction('确认记录'));
      expect(patient.doseCompletions, hasLength(1));
      expect(tester.takeException(), isNull);
      await selectTab(tester, '用药计划');
      await tapVisible(tester, find.text('查看处方'));
      expect(find.byType(HistoryPage), findsOneWidget);
      expect(find.text('处方与用药详情'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
