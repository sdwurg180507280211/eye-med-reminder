import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eye_med_reminder/storage.dart';
import 'package:eye_med_reminder/models.dart';

class ControlledStorage extends FlutterSecureStorage {
  bool failNextWrite = false;
  final writes = <String>[];
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
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failNextWrite) {
      failNextWrite = false;
      throw PlatformException(code: 'write_failed');
    }
    if (value != null) {
      writes.add(value);
    }
    await super.write(key: key, value: value);
  }
}

Patient fixturePatient(String id) => Patient(
  id: id,
  name: '王',
  salt: '',
  hash: '',
  plans: [
    Plan(
      id: 'plan-$id',
      created: DateTime(2026, 10, 4),
      medications: [
        Medication(
          id: 'med',
          name: '人工泪液',
          eye: '双眼',
          dose: '1滴',
          frequency: '每日2次',
          start: DateTime(2026, 10, 4),
          days: 2,
          times: ['08:00', '12:00'],
        ),
      ],
      review: DateTime(2026, 10, 5),
      reviewDays: [1],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'reopening restores records; same-name profiles are isolated by password',
    () async {
      final store = PatientStore();
      await store.load();
      final a = await store.create('张建国', '123456');
      await store.create('张建国', '654321');
      a.plans.add(
        Plan(
          id: 'plan1',
          created: DateTime(2026, 10, 4),
          medications: [
            Medication(
              id: 'm1',
              name: '玻璃酸钠滴眼液',
              eye: '左眼',
              dose: '1滴',
              frequency: '每日1次',
              start: DateTime(2026, 10, 4),
              days: 7,
              times: ['08:00'],
            ),
          ],
        ),
      );
      await store.save();
      final reopened = PatientStore();
      await reopened.load();
      expect(
        (await reopened.login(
          '张建国',
          '123456',
        ))!.plans.single.medications.single.eye,
        '左眼',
      );
      expect((await reopened.login('张建国', '654321'))!.plans, isEmpty);
      expect(await reopened.login('张建国', '000000'), isNull);
      expect(await reopened.login('李', '123456'), isNull);
      final raw = await const FlutterSecureStorage().read(key: 'patients_v1');
      expect(raw, isNot(contains('123456')));
      expect(raw, isNot(contains('654321')));
      expect(reopened.patients[0].salt, isNot(reopened.patients[1].salt));
    },
  );
  test(
    'duplicate identity is rejected and corrupt data is not overwritten',
    () async {
      final store = PatientStore();
      await store.create('王', '123456');
      await expectLater(store.create('王', '123456'), throwsStateError);
      expect(store.patients.length, 1);
      await const FlutterSecureStorage().write(
        key: 'patients_v1',
        value: '{broken',
      );
      await expectLater(PatientStore().load(), throwsFormatException);
      expect(
        await const FlutterSecureStorage().read(key: 'patients_v1'),
        '{broken',
      );
    },
  );
  test('password derivation is deterministic for a salt', () async {
    final store = PatientStore();
    final salt = base64Encode(List.filled(16, 7));
    expect(
      await store.derive('123456', salt),
      await store.derive('123456', salt),
    );
    expect(
      await store.derive('123456', salt),
      isNot(await store.derive('654321', salt)),
    );
  });

  test(
    'completion and pause survive reopening and undo is persisted',
    () async {
      final store = PatientStore();
      final patient = fixturePatient('a');
      store.patients.add(patient);
      final plan = patient.plans.single;
      final dose = eventsFor(
        plan,
        plan.created,
      ).firstWhere((e) => e.medication != null);
      final recordedAt = DateTime(2026, 10, 4, 8, 5);
      await store.setDoseCompleted(patient, dose, true, now: recordedAt);
      await store.setPlanPaused(patient, plan, true);
      final reopened = PatientStore();
      await reopened.load();
      final restored = reopened.patients.single;
      expect(restored.plans.single.remindersPaused, isTrue);
      expect(restored.doseCompletions[dose.occurrenceKey], recordedAt);
      await store.setDoseCompleted(patient, dose, false);
      await reopened.load();
      expect(reopened.patients.single.doseCompletions, isEmpty);
      expect(patient.plans.single.medications, hasLength(1));
    },
  );

  test('failed durable writes roll back pause, completion and undo', () async {
    final storage = ControlledStorage();
    final store = PatientStore(storage: storage);
    final patient = fixturePatient('a');
    store.patients.add(patient);
    await store.save();
    final plan = patient.plans.single;
    final dose = eventsFor(
      plan,
      plan.created,
    ).firstWhere((e) => e.medication != null);
    final now = DateTime(2026, 10, 4, 8, 5);
    storage.failNextWrite = true;
    await expectLater(
      store.setPlanPaused(patient, plan, true),
      throwsA(isA<PlatformException>()),
    );
    expect(plan.remindersPaused, isFalse);
    storage.failNextWrite = true;
    await expectLater(
      store.setDoseCompleted(patient, dose, true, now: now),
      throwsA(isA<PlatformException>()),
    );
    expect(patient.doseCompletions, isEmpty);
    await store.setDoseCompleted(patient, dose, true, now: now);
    storage.failNextWrite = true;
    await expectLater(
      store.setDoseCompleted(patient, dose, false),
      throwsA(isA<PlatformException>()),
    );
    expect(patient.doseCompletions[dose.occurrenceKey], now);
    final restored = PatientStore();
    await restored.load();
    expect(restored.patients.single.doseCompletions[dose.occurrenceKey], now);
  });

  test(
    'recording rejects future, review, paused and other profile doses',
    () async {
      final store = PatientStore();
      final patient = fixturePatient('a');
      final other = fixturePatient('b');
      store.patients.addAll([patient, other]);
      final plan = patient.plans.single;
      final events = eventsFor(plan, plan.created);
      final dose = events.firstWhere((e) => e.medication != null);
      final review = events.firstWhere((e) => e.medication == null);
      await expectLater(
        store.setDoseCompleted(
          patient,
          dose,
          true,
          now: DateTime(2026, 10, 4, 7),
        ),
        throwsStateError,
      );
      await expectLater(
        store.setDoseCompleted(patient, review, true),
        throwsStateError,
      );
      await expectLater(
        store.setDoseCompleted(other, dose, true),
        throwsStateError,
      );
      await expectLater(
        store.setPlanPaused(other, plan, true),
        throwsStateError,
      );
      await store.setPlanPaused(patient, plan, true);
      await expectLater(
        store.setDoseCompleted(
          patient,
          dose,
          true,
          now: DateTime(2026, 10, 4, 9),
        ),
        throwsStateError,
      );
      expect(patient.doseCompletions, isEmpty);
      expect(other.doseCompletions, isEmpty);
    },
  );

  test(
    'serialized mutations preserve a successful write after a rollback',
    () async {
      final storage = ControlledStorage();
      final store = PatientStore(storage: storage);
      final patient = fixturePatient('a');
      final other = fixturePatient('b');
      store.patients.addAll([patient, other]);
      final events = eventsFor(
        patient.plans.single,
        DateTime(2026, 10, 4),
      ).where((e) => e.medication != null).toList();
      storage.failNextWrite = true;
      final failed = store.setDoseCompleted(
        patient,
        events[0],
        true,
        now: DateTime(2026, 10, 4, 13),
      );
      final successful = store.setDoseCompleted(
        patient,
        events[1],
        true,
        now: DateTime(2026, 10, 4, 13),
      );
      await expectLater(failed, throwsA(isA<PlatformException>()));
      await successful;
      expect(patient.isCompleted(events[0]), isFalse);
      expect(patient.isCompleted(events[1]), isTrue);
      expect(other.doseCompletions, isEmpty);
      final restored = PatientStore();
      await restored.load();
      expect(restored.patients.first.doseCompletions.keys, [
        events[1].occurrenceKey,
      ]);
      expect(restored.patients.last.doseCompletions, isEmpty);
    },
  );
}
