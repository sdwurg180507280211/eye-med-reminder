import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_med_reminder/design_system.dart';
import 'package:eye_med_reminder/dog_avatar.dart';
import 'package:eye_med_reminder/forms.dart';
import 'package:eye_med_reminder/models.dart';
import 'package:eye_med_reminder/storage.dart';

class _PendingLoginStore extends PatientStore {
  int attempts = 0;
  final result = Completer<Patient?>();
  @override
  Future<Patient?> login(String name, String pin) {
    attempts++;
    return result.future;
  }
}

Patient _patient() =>
    Patient(id: 'patient', name: '小明', salt: '', hash: '', plans: []);

Medication _medication({DateTime? start}) => Medication(
  id: 'medicine',
  name: '人工泪液',
  eye: '左眼',
  dose: '按处方填写的剂量',
  frequency: '每日1次',
  start: start ?? DateTime(2026, 10, 4),
  days: 7,
  times: ['08:00'],
);

Future<void> _pumpNarrow(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: eyeMedTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: page,
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login remains usable at 320 pixels with doubled text', (
    tester,
  ) async {
    await _pumpNarrow(
      tester,
      LoginPage(store: PatientStore(), onLogin: (_) async {}),
    );
    await _tapVisible(tester, find.text('进入我的档案'));
    expect(find.text('请输入姓名'), findsOneWidget);
    expect(find.text('密码必须为6位数字'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tapVisible(tester, find.text('创建患者档案'));
    expect(find.byKey(const ValueKey('repeat-pin')), findsOneWidget);
    await _tapVisible(tester, find.text('返回登录'));
    expect(find.byKey(const ValueKey('repeat-pin')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN toggle preserves input and keyboard submits only once', (
    tester,
  ) async {
    final store = _PendingLoginStore();
    final entered = Completer<void>();
    int callbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: eyeMedTheme(),
        home: LoginPage(
          store: store,
          onLogin: (_) async {
            callbacks++;
            await entered.future;
          },
        ),
      ),
    );
    final name = find.byKey(const ValueKey('patient-name'));
    final pin = find.byKey(const ValueKey('login-pin'));
    await tester.enterText(name, '小明');
    await tester.enterText(pin, '123456');
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(of: pin, matching: find.byType(EditableText)),
    );
    expect(editable.obscureText, isFalse);
    expect(editable.enableSuggestions, isFalse);
    expect(editable.controller.text, '123456');
    editable.onSubmitted!('123456');
    editable.onSubmitted!('123456');
    await tester.pump();
    expect(store.attempts, 1);
    expect(find.text('正在处理…'), findsOneWidget);
    store.result.complete(_patient());
    await tester.pump();
    editable.onSubmitted!('123456');
    expect(store.attempts, 1);
    expect(callbacks, 1);
    entered.complete();
    await tester.pumpAndSettle();
    expect(find.text('进入我的档案'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login exposes actionable mismatch and permits retry', (
    tester,
  ) async {
    final store = _PendingLoginStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: eyeMedTheme(),
        home: LoginPage(store: store, onLogin: (_) async {}),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('patient-name')), '小明');
    await tester.enterText(find.byKey(const ValueKey('login-pin')), '123456');
    await _tapVisible(tester, find.text('进入我的档案'));
    store.result.complete(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('首次使用请创建患者档案'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('patient-name')), '小红');
    await tester.pump();
    expect(find.textContaining('首次使用请创建患者档案'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editor validates in place with large text and updates eye feedback',
    (tester) async {
      await _pumpNarrow(tester, const MedicationEditor());
      await _tapVisible(tester, find.text('添加到用药计划'));
      expect(find.text('请输入药品名称'), findsOneWidget);
      expect(find.text('请输入剂量'), findsOneWidget);
      expect(find.text('请选择用药眼别'), findsOneWidget);
      expect(find.text('请选择频次'), findsOneWidget);
      expect(find.text('请输入1–365天，较长疗程请分段确认'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, find.text('左眼'));
      expect(find.text('请选择用药眼别'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editor frequency menu and selected time count fit narrow screen',
    (tester) async {
      await _pumpNarrow(tester, MedicationEditor(medication: _medication()));
      expect(find.text('已选1个时间 · 需要1个'), findsOneWidget);
      await _tapVisible(tester, find.text('每日1次'));
      await _tapVisible(tester, find.text('每日2次').last);
      expect(find.text('已选1个时间 · 需要2个'), findsOneWidget);
      await _tapVisible(tester, find.text('保存修改'));
      expect(find.text('提醒时间数量应与每日2次一致，请核对'), findsOneWidget);
      await _tapVisible(tester, find.text('12:00'));
      expect(find.text('已选2个时间 · 需要2个'), findsOneWidget);
      expect(find.text('提醒时间数量应与每日2次一致，请核对'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsaved editor change can be kept or discarded', (tester) async {
    Medication? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: eyeMedTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                saved = await Navigator.push<Medication>(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicationEditor()),
                );
              },
              child: const Text('打开录入'),
            ),
          ),
        ),
      ),
    );
    await _tapVisible(tester, find.text('打开录入'));
    await tester.enterText(
      find.byKey(const ValueKey('medication-name')),
      '人工泪液',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await _tapVisible(tester, find.text('继续编辑'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('medication-name')))
          .controller!
          .text,
      '人工泪液',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('放弃修改'));
    expect(find.text('打开录入'), findsOneWidget);
    expect(saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing retains identity and saves without discard prompt', (
    tester,
  ) async {
    Medication? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: eyeMedTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                saved = await Navigator.push<Medication>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicationEditor(medication: _medication()),
                  ),
                );
              },
              child: const Text('打开编辑'),
            ),
          ),
        ),
      ),
    );
    await _tapVisible(tester, find.text('打开编辑'));
    await tester.enterText(
      find.byKey(const ValueKey('medication-name')),
      '人工泪液（处方）',
    );
    await _tapVisible(tester, find.text('保存修改'));
    expect(saved!.id, 'medicine');
    expect(saved!.name, '人工泪液（处方）');
    expect(find.text('放弃未保存的修改？'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('historical medication date stays within date-picker bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: eyeMedTheme(),
        home: MedicationEditor(
          medication: _medication(start: DateTime(2018, 5, 1)),
        ),
      ),
    );
    await _tapVisible(tester, find.text('疗程开始日期：2018-05-01'));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dog animation observes the reduced-motion preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: DogAvatar(animate: true),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DogAvatar),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter! as DogPainter).mouth, 0);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
