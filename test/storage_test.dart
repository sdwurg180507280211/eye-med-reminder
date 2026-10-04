import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eye_med_reminder/storage.dart';
import 'package:eye_med_reminder/models.dart';

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
}
