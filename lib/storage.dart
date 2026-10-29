import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class PatientStore {
  final FlutterSecureStorage storage;
  List<Patient> patients = [];
  Future<void> _tail = Future.value();
  PatientStore({this.storage = const FlutterSecureStorage()});
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> load() => _serialize(() async {
    final raw = await storage.read(key: 'patients_v1');
    patients = raw == null ? [] : Patient.decode(raw);
  });

  Future<void> save() => _serialize(_write);
  Future<void> _write() => storage.write(
    key: 'patients_v1',
    value: jsonEncode(patients.map((p) => p.toJson()).toList()),
  );

  void _requirePlan(Patient patient, Plan plan) {
    if (!patients.contains(patient) || !patient.plans.contains(plan)) {
      throw StateError('该用药计划不属于当前档案');
    }
  }

  Future<void> setPlanPaused(Patient patient, Plan plan, bool paused) =>
      _serialize(() async {
        _requirePlan(patient, plan);
        final previous = plan.remindersPaused;
        if (previous == paused) {
          return;
        }
        plan.remindersPaused = paused;
        try {
          await _write();
        } catch (_) {
          plan.remindersPaused = previous;
          rethrow;
        }
      });

  Future<void> setDoseCompleted(
    Patient patient,
    ReminderEvent event,
    bool completed, {
    DateTime? now,
  }) => _serialize(() async {
    _requirePlan(patient, event.plan);
    final medication = event.medication;
    if (medication == null || !event.plan.medications.contains(medication)) {
      throw StateError('仅可记录当前档案中的用药');
    }
    final recordedAt = now ?? DateTime.now();
    if (completed &&
        (event.plan.remindersPaused || event.at.isAfter(recordedAt))) {
      throw StateError('仅可记录已到时间且未暂停的用药');
    }
    final key = event.occurrenceKey;
    final previous = patient.doseCompletions[key];
    if (completed == (previous != null)) {
      return;
    }
    if (completed) {
      patient.doseCompletions[key] = recordedAt;
    } else {
      patient.doseCompletions.remove(key);
    }
    try {
      await _write();
    } catch (_) {
      if (previous == null) {
        patient.doseCompletions.remove(key);
      } else {
        patient.doseCompletions[key] = previous;
      }
      rethrow;
    }
  });
  Future<String> derive(String pin, String salt) async {
    final key =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 100000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(pin)),
          nonce: base64Decode(salt),
        );
    return base64Encode(await key.extractBytes());
  }

  Future<Patient?> login(String name, String pin) async {
    for (final p in patients.where((p) => p.name == name)) {
      if (await derive(pin, p.salt) == p.hash) {
        return p;
      }
    }
    return null;
  }

  Future<Patient> create(String name, String pin) => _serialize(() async {
    if (await login(name, pin) != null) {
      throw StateError('该档案已存在，请返回登录');
    }
    final salt = base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final p = Patient(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      salt: salt,
      hash: await derive(pin, salt),
      plans: [],
    );
    patients.add(p);
    try {
      await _write();
    } catch (_) {
      patients.remove(p);
      rethrow;
    }
    return p;
  });
}
