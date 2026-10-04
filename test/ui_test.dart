import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eye_med_reminder/main.dart';
import 'package:eye_med_reminder/storage.dart';
import 'package:eye_med_reminder/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('login validates six digits without a test-reminder button', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(store: PatientStore(), onLogin: (_) async {}),
      ),
    );
    await tester.tap(find.text('进入我的档案'));
    await tester.pump();
    expect(find.text('请输入姓名'), findsOneWidget);
    expect(find.text('密码必须为6位数字'), findsOneWidget);
    expect(find.text('测试用药提醒页面'), findsNothing);
  });
  testWidgets('medicine editor requires clinical fields and matching times', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicationEditor()));
    await tester.ensureVisible(find.text('添加到用药计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加到用药计划'));
    await tester.pump();
    expect(find.text('请输入药品名称'), findsOneWidget);
    expect(find.text('请输入剂量'), findsOneWidget);
    expect(find.text('请选择频次'), findsOneWidget);
    expect(find.text('请输入1–365天，较长疗程请分段确认'), findsOneWidget);
    expect(find.text('每眼1滴'), findsNothing);
  });
  testWidgets(
    'voice failure preserves static dog, exact medicine text and exit',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            call,
          ) async {
            if (call.method == 'speak') {
              throw PlatformException(code: 'unavailable');
            }
            return 1;
          });
      final m = Medication(
        id: 'm',
        name: '人工泪液',
        eye: '右眼',
        dose: '每次1滴',
        frequency: '每日1次',
        start: DateTime(2026, 10, 4),
        days: 1,
        times: ['08:00'],
      );
      final p = Plan(id: 'p', created: m.start, medications: [m]);
      await tester.pumpWidget(
        MaterialApp(
          home: ReminderPage(name: '张建国', event: eventsFor(p, m.start).single),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('人工泪液'), findsOneWidget);
      expect(find.text('右眼 · 每次1滴'), findsOneWidget);
      expect(find.text('请按上方文字核对本次提醒。'), findsOneWidget);
      expect(find.byType(DogAvatar), findsOneWidget);
      expect(tester.widget<DogAvatar>(find.byType(DogAvatar)).animate, isFalse);
      expect(find.text('查看药物说明'), findsOneWidget);
      expect(find.text('结束提醒'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    },
  );
}
