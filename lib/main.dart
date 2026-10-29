import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'storage.dart';
import 'notifications.dart';
import 'drug_catalog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EyeMedApp());
}

class EyeMedApp extends StatelessWidget {
  const EyeMedApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '眼科用药提醒助手',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff0d6b4f),
        primary: const Color(0xff0d6b4f),
        surface: const Color(0xffffffff),
      ),
      scaffoldBackgroundColor: const Color(0xfff4f8f5),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xff0f291e)),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff0f291e)),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff0f291e)),
        bodyLarge: TextStyle(fontSize: 17, color: Color(0xff1e3a2b)),
        bodyMedium: TextStyle(fontSize: 16, color: Color(0xff3d5a4c)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xffffffff),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xffd5e5db), width: 1.2),
        ),
      ),
    ),
    home: const PatientHome(),
  );
}

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});
  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> with WidgetsBindingObserver {
  final store = PatientStore();
  final notifications = ReminderNotifications();
  Patient? patient;
  bool loading = true, loadFailed = false;
  int tab = 0;
  String? pendingPayload;
  Timer? ticker;
  DateTime lastTick = DateTime.now();
  final seen = <String>{};
  final Set<String> checkedInEventKeys = {};
  final queue = <ReminderEvent>[];
  bool showingReminder = false;
  List<Medication> draft = [];
  DateTime? review;
  Set<int> reviewDays = {};
  String? photo;
  bool saving = false;
  String notificationStatus = '正在准备系统提醒…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    boot();
  }

  Future<void> boot() async {
    try {
      await store.load();
    } catch (_) {
      loadFailed = true;
    }
    try {
      await notifications.initialize(openPayload);
      pendingPayload = notifications.launchKey;
    } catch (_) {
      /* UI remains usable without notification services. */
    }
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => checkDue());
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && patient != null) {
      checkDue();
      refreshNotifications();
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> refreshNotifications() async {
    final current = patient;
    if (current == null) {
      return;
    }
    try {
      if (!await notifications.schedule(current)) {
        notificationStatus = '系统通知未开启；请在手机设置中允许通知。';
        message('系统提醒未开启，请在手机设置中允许通知。应用打开时仍会显示提醒。');
      } else {
        final until = notifications.scheduledUntil;
        notificationStatus = until == null
            ? '暂无后续提醒。'
            : '系统提醒已安排至${dateLabel(until)} ${clockLabel(until)}。请在此之前打开应用以续排提醒。${notifications.exact ? '' : '精确闹钟未授权，通知可能延迟。'}';
      }
    } catch (_) {
      notificationStatus = '系统提醒暂未安排成功，请检查手机通知设置。';
      message('系统提醒暂未安排成功；请重新打开应用并检查通知权限。');
    }
    if (mounted) {
      setState(() {});
    }
  }

  void openPayload(String payload) {
    if (patient == null) {
      pendingPayload = payload;
      return;
    }
    final parts = payload.split('#');
    if (parts.length != 2 || parts.first != patient!.id) {
      return;
    }
    {
      // Reconstruct the scheduled event including midnight offsets.
      final dateText = parts.last.split('|').last;
      final date = DateTime.tryParse(dateText);
      if (date == null) {
        return;
      }
      final candidates = [
        ...patientEventsFor(patient!, date),
        ...patientEventsFor(
          patient!,
          DateTime(date.year, date.month, date.day - 1),
        ),
      ];
      for (final e in candidates) {
        if (e.key == parts.last) {
          queue.add(e);
          showNextReminder();
          return;
        }
      }
    }
  }

  void checkDue() {
    final now = DateTime.now();
    if (patient != null &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      final since = lastTick.isBefore(now.subtract(const Duration(minutes: 5)))
          ? now.subtract(const Duration(minutes: 5))
          : lastTick;
      {
        for (final date in [
          DateTime(now.year, now.month, now.day - 1),
          day(now),
        ]) {
          for (final e in patientEventsFor(patient!, date)) {
            if (e.at.isAfter(since) && !e.at.isAfter(now) && seen.add(e.key)) {
              queue.add(e);
            }
          }
        }
      }
      showNextReminder();
    }
    lastTick = now;
  }

  Future<void> showNextReminder() async {
    if (showingReminder || queue.isEmpty || patient == null || !mounted) {
      return;
    }
    showingReminder = true;
    final event = queue.removeAt(0);
    seen.add(event.key);
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReminderPage(name: patient!.name, event: event),
      ),
    );
    if (res == true && event.medication != null) {
      checkedInEventKeys.add("${event.medication!.id}_${clockLabel(event.at)}");
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => tab = 0);
    }
    showingReminder = false;
    showNextReminder();
  }

  Future<void> signedIn(Patient p) async {
    setState(() {
      patient = p;
      tab = p.plans.isEmpty ? 2 : 0;
      draft = [];
      review = null;
      reviewDays = {};
      photo = null;
    });
    lastTick = DateTime.now();
    seen.clear();
    if (pendingPayload != null) {
      final payload = pendingPayload!;
      pendingPayload = null;
      openPayload(payload);
    }
    await refreshNotifications();
  }

  Future<void> editMedication([int? index]) async {
    final m = await Navigator.of(context).push<Medication>(
      MaterialPageRoute(
        builder: (_) =>
            MedicationEditor(medication: index == null ? null : draft[index]),
      ),
    );
    if (m != null && mounted) {
      setState(() {
        if (index == null) {
          draft.add(m);
        } else {
          draft[index] = m;
        }
        tab = 1;
      });
    }
  }

  Future<void> pick(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (image == null || !mounted) {
        return;
      }
      final dir = await getApplicationSupportDirectory();
      final saved = await File(image.path).copy(
        '${dir.path}/rx_${patient!.id}_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      if (mounted) {
        setState(() => photo = saved.path);
      }
    } catch (_) {
      message('未能获取照片，请检查相机或相册权限，也可以手动添加药物。');
    }
  }

  Future<void> confirm() async {
    if (saving) {
      return;
    }
    if (draft.isEmpty) {
      message('请至少添加一种药物');
      return;
    }
    if (review == null && reviewDays.isNotEmpty) {
      message('请先选择复查日期');
      return;
    }
    // Reject accidental duplicate medicine/time entries; do not silently double-dose.
    final checked = patient!.plans.expand((p) => p.medications).toList();
    for (final m in draft) {
      final end = DateTime(m.start.year, m.start.month, m.start.day + m.days);
      if (checked.any((old) {
        final oldEnd = DateTime(
          old.start.year,
          old.start.month,
          old.start.day + old.days,
        );
        final eyesOverlap =
            old.eye == m.eye || old.eye == '双眼' || m.eye == '双眼';
        return old.name.trim() == m.name.trim() &&
            eyesOverlap &&
            m.start.isBefore(oldEnd) &&
            old.start.isBefore(end) &&
            m.times.any(old.times.contains);
      })) {
        message('已有同名药物在重叠疗程、相同眼别和时间使用，请核对，避免重复提醒');
        return;
      }
      checked.add(m);
    }
    setState(() => saving = true);
    final p = Plan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      created: DateTime.now(),
      medications: List.of(draft),
      review: review,
      reviewDays: reviewDays.toList()..sort(),
      photo: photo,
    );
    patient!.plans.add(p);
    try {
      await store.save();
    } catch (_) {
      patient!.plans.remove(p);
      if (mounted) {
        setState(() => saving = false);
        message('保存失败，用药计划尚未开启，请重试');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      saving = false;
      draft = [];
      photo = null;
      review = null;
      reviewDays = {};
      tab = 0;
    });
    message('计划已保存');
    await refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadFailed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('本地档案读取失败，为保护现有记录，暂不写入新数据。'),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      loading = true;
                      loadFailed = false;
                    });
                    boot();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (patient == null) {
      return LoginPage(store: store, onLogin: signedIn);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('眼科用药提醒助手')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: tab == 0
              ? mine()
              : tab == 1
              ? plan()
              : capture(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
          NavigationDestination(icon: Icon(Icons.schedule), label: '用药计划'),
          NavigationDestination(
            icon: Icon(Icons.add_a_photo_outlined),
            label: '添加处方',
          ),
        ],
      ),
    );
  }

  List<Widget> capture() => [
    panel([
      const DogAvatar(),
      Text('${patient!.name}，请添加处方', style: titleStyle),
      const Text('可以拍摄处方，也可以直接手动添加药物'),
    ]),
    panel([
      FilledButton.icon(
        onPressed: () => pick(ImageSource.camera),
        icon: const Icon(Icons.camera_alt),
        label: const Text('拍摄处方'),
      ),
      OutlinedButton.icon(
        onPressed: () => pick(ImageSource.gallery),
        icon: const Icon(Icons.photo),
        label: const Text('从相册选择'),
      ),
      if (photo != null) ...[
        Image.file(
          File(photo!),
          height: 220,
          errorBuilder: (_, _, _) => const Text('照片暂不可用'),
        ),
        const Text('照片已保留。处方识别尚未接入，请对照照片手动填写，不会自动生成药物。'),
      ],
      FilledButton(
        onPressed: () => editMedication(),
        child: const Text('＋ 手动添加药物'),
      ),
    ]),
  ];
  List<Widget> plan() => [
    panel([
      const Text('确认用药计划', style: titleStyle),
      const Text('请按照医生实际指导核对。识别不到的内容请自行填写，不根据药物常规用法自动补齐。'),
    ]),
    if (photo != null)
      panel([
        Image.file(
          File(photo!),
          height: 220,
          errorBuilder: (_, _, _) => const Text('处方照片暂不可用'),
        ),
        const Text('请对照处方核对下方用药信息。'),
      ]),
    panel([
      const Text('本次复查', style: sectionStyle),
      OutlinedButton(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: review ?? day(DateTime.now()),
            firstDate: day(DateTime.now()),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) {
            setState(() => review = d);
          }
        },
        child: Text(review == null ? '选择复查日期（可不填）' : dateLabel(review!)),
      ),
      if (review != null)
        TextButton(
          onPressed: () => setState(() {
            review = null;
            reviewDays.clear();
          }),
          child: const Text('清除复查日期'),
        ),
      Wrap(
        spacing: 8,
        children: [3, 2, 1]
            .map(
              (d) => FilterChip(
                label: Text('提前$d天'),
                selected: reviewDays.contains(d),
                onSelected: (v) => setState(() {
                  v ? reviewDays.add(d) : reviewDays.remove(d);
                }),
              ),
            )
            .toList(),
      ),
      const Text('可多选，未选中则不提前提醒；提前提醒时间为08:00。'),
    ]),
    if (draft.isEmpty) panel([const Text('暂无药物，请手动添加。')]),
    for (var i = 0; i < draft.length; i++)
      panel([
        Row(
          children: [
            Expanded(
              child: Text('第${i + 1}种 · ${draft[i].name}', style: sectionStyle),
            ),
            IconButton(
              tooltip: '上移',
              onPressed: i == 0
                  ? null
                  : () => setState(() {
                      final m = draft.removeAt(i);
                      draft.insert(i - 1, m);
                    }),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: '下移',
              onPressed: i == draft.length - 1
                  ? null
                  : () => setState(() {
                      final m = draft.removeAt(i);
                      draft.insert(i + 1, m);
                    }),
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
        Row(
          children: [
            const Text('眼别：', style: TextStyle(fontWeight: FontWeight.bold)),
            ...['左眼', '右眼', '双眼'].map(
              (e) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(e),
                  selected: draft[i].eye == e,
                  onSelected: (_) => setState(() {
                    draft[i] = Medication(
                      id: draft[i].id,
                      name: draft[i].name,
                      eye: e,
                      dose: draft[i].dose,
                      frequency: draft[i].frequency,
                      start: draft[i].start,
                      days: draft[i].days,
                      times: draft[i].times,
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('频次：', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: frequencies.contains(draft[i].frequency)
                  ? draft[i].frequency
                  : frequencies.first,
              items: frequencies
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    draft[i] = Medication(
                      id: draft[i].id,
                      name: draft[i].name,
                      eye: draft[i].eye,
                      dose: draft[i].dose,
                      frequency: val,
                      start: draft[i].start,
                      days: draft[i].days,
                      times: draft[i].times,
                    );
                  });
                }
              },
            ),
            const Spacer(),
            ActionChip(
              avatar: const Icon(Icons.tune_outlined, size: 18, color: Color(0xff0d6b4f)),
              label: Text(
                '${draft[i].days} 天 (滑轮选择)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff0c261c)),
              ),
              backgroundColor: const Color(0xffe8f5f0),
              side: const BorderSide(color: Color(0xffb7dfcc), width: 1.5),
              onPressed: () => showDaysWheelPicker(i),
            ),
          ],
        ),
        Text('剂量：${draft[i].dose} · 记录日期：${dateLabel(draft[i].start)}'),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('原始时间：', style: TextStyle(fontWeight: FontWeight.bold)),
            ...draft[i].times.map(
              (t) => InputChip(
                label: Text(t),
                tooltip: '删除此时间',
                onDeleted: () => setState(() {
                  final updated = List<String>.from(draft[i].times)..remove(t);
                  draft[i] = Medication(
                    id: draft[i].id,
                    name: draft[i].name,
                    eye: draft[i].eye,
                    dose: draft[i].dose,
                    frequency: draft[i].frequency,
                    start: draft[i].start,
                    days: draft[i].days,
                    times: updated,
                  );
                }),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('添加时间'),
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 8, minute: 0),
                  builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (time != null) {
                  final str =
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  setState(() {
                    final set = {...draft[i].times, str}.toList()..sort();
                    draft[i] = Medication(
                      id: draft[i].id,
                      name: draft[i].name,
                      eye: draft[i].eye,
                      dose: draft[i].dose,
                      frequency: draft[i].frequency,
                      start: draft[i].start,
                      days: draft[i].days,
                      times: set,
                    );
                  });
                }
              },
            ),
          ],
        ),
        Text(
          '实际时间：${previewTimes(i)}',
          style: const TextStyle(color: Color(0xff0d6b4f), fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => editMedication(i),
              child: const Text('完整修改'),
            ),
            TextButton(
              onPressed: () => drugInfo(context, draft[i].name),
              child: const Text('药物说明'),
            ),
            TextButton(
              onPressed: () => setState(() => draft.removeAt(i)),
              child: const Text('删除'),
            ),
          ],
        ),
      ]),
    OutlinedButton(
      onPressed: () => editMedication(),
      child: const Text('＋ 手动新增用药'),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('同一提醒时间的药物按上方顺序错开10分钟。实际时间可能因疗程重叠情况变化；若医生另有指定，以医生指导为准。'),
    ),
    FilledButton(
      onPressed: saving ? null : confirm,
      child: Text(saving ? '正在保存…' : '确认并开启提醒'),
    ),
  ];
  String previewTimes(int i) {
    final p = Plan(id: 'draft', created: DateTime.now(), medications: draft);
    final preview = Patient(
      id: patient!.id,
      name: patient!.name,
      salt: '',
      hash: '',
      plans: [...patient!.plans, p],
    );
    return patientEventsFor(preview, draft[i].start)
        .where((e) => e.medication?.id == draft[i].id)
        .map(
          (e) =>
              '${clockLabel(e.at)}${day(e.at) != day(draft[i].start) ? '（次日）' : ''}',
        )
        .join('、');
  }

  
  void showDaysWheelPicker(int i) {
    int selected = draft[i].days;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: 340,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(fontSize: 16)),
                    ),
                    Text(
                      '${draft[i].name} · 疗程天数',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xff0c261c)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0d6b4f),
                        minimumSize: const Size(64, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          draft[i] = Medication(
                            id: draft[i].id,
                            name: draft[i].name,
                            eye: draft[i].eye,
                            dose: draft[i].dose,
                            frequency: draft[i].frequency,
                            start: draft[i].start,
                            days: selected,
                            times: draft[i].times,
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 44,
                  perspective: 0.004,
                  diameterRatio: 1.3,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: (draft[i].days - 1).clamp(0, 179),
                  ),
                  onSelectedItemChanged: (idx) {
                    setSheetState(() => selected = idx + 1);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 180,
                    builder: (ctx, idx) {
                      final val = idx + 1;
                      final isCurrent = val == selected;
                      return Center(
                        child: Text(
                          '$val 天',
                          style: TextStyle(
                            fontSize: isCurrent ? 22 : 17,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? const Color(0xff0d6b4f) : const Color(0xff64748b),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> mine() {
    final now = DateTime.now();
    final today = <ReminderEvent>[];
    {
      today.addAll(
        [
          ...patientEventsFor(
            patient!,
            DateTime(now.year, now.month, now.day - 1),
          ),
          ...patientEventsFor(patient!, day(now)),
        ].where((e) => day(e.at) == day(now) && e.medication != null),
      );
    }
    today.sort((a, b) => a.at.compareTo(b.at));
    return [
      panel([
        Row(
          children: [
            Expanded(child: Text('${patient!.name}，您好！', style: titleStyle)),
            const DogAvatar(size: 70),
          ],
        ),
        const Text('按时用药，守护眼睛健康。'),
      ]),
      () {
        final futurePlans = patient!.plans.where(
          (p) => p.review != null && !day(p.review!).isBefore(day(now)),
        ).toList();
        final revDate = futurePlans.isNotEmpty ? futurePlans.first.review : review ?? DateTime(now.year, now.month, now.day + 7);
        final diff = revDate.difference(day(now)).inDays;
        final statusText = diff > 0
            ? '距离门诊复查还有 $diff 天（请提前挂号预约）'
            : diff == 0
                ? '今天就是复查日！请备齐病历本按时就诊'
                : '已过复查日期';
        return panel([
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, color: Color(0xff0d6b4f), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('门诊复查日期：${dateLabel(revDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff0c261c))),
                    const SizedBox(height: 3),
                    Text(statusText, style: const TextStyle(fontSize: 14, color: Color(0xff2e4d3f), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: const Text('修改 ›'),
              ),
            ],
          ),
        ]);
      }(),
      panel([
        Text(notificationStatus),
        const Text('后台通过系统通知提醒；点击通知进入小狗动画与语音页面。'),
      ]),
      panel([
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('⏰ 今日用药时间轴', style: sectionStyle),
            Text(
              '${today.where((e) => checkedInEventKeys.contains("${e.medication?.id}_${clockLabel(e.at)}")).length} / ${today.length} 次',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff0d6b4f), fontSize: 16),
            ),
          ],
        ),
        if (today.isNotEmpty) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: today.isEmpty ? 0 : today.where((e) => checkedInEventKeys.contains("${e.medication?.id}_${clockLabel(e.at)}")).length / today.length,
              minHeight: 8,
              backgroundColor: const Color(0xffe2ede6),
              valueColor: const AlwaysStoppedAnimation(Color(0xff0d6b4f)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (today.isEmpty) const Text('今天没有用药提醒'),
        for (var idx = 0; idx < today.length; idx++) ...[
          () {
            final e = today[idx];
            final key = "${e.medication?.id}_${clockLabel(e.at)}";
            final isDone = checkedInEventKeys.contains(key);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xfff0fdf4) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDone ? const Color(0xff86efac) : const Color(0xffd5e5db),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8f5f0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          clockLabel(e.at),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0d6b4f),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0c261c),
                          ),
                        ),
                      ),
                      if (isDone)
                        const Chip(
                          label: Text('已滴眼', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: Color(0xff059669),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(e.body, style: const TextStyle(fontSize: 15, color: Color(0xff2e4d3f))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDone ? const Color(0xff059669) : const Color(0xff0d6b4f),
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() {
                              if (isDone) {
                                checkedInEventKeys.remove(key);
                              } else {
                                checkedInEventKeys.add(key);
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isDone ? '已撤销本次打卡' : '🎉 打卡成功！已滴眼，请闭目休息3分钟。'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xff0d6b4f),
                              ),
                            );
                          },
                          icon: Icon(isDone ? Icons.check_circle : Icons.water_drop, size: 18),
                          label: Text(isDone ? '已完成滴眼' : '💧 确认已滴眼打卡'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => drugInfo(context, e.title),
                        child: const Text('说明'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }(),
        ],
      ]),
      panel([
        const Text('复查提醒', style: sectionStyle),
        if (!patient!.plans.any(
          (p) => p.review != null && !day(p.review!).isBefore(day(now)),
        ))
          const Text('尚未设置后续复查日期'),
        for (final p in patient!.plans.where(
          (p) => p.review != null && !day(p.review!).isBefore(day(now)),
        ))
          Text(
            '${dateLabel(p.review!)} · ${p.reviewDays.isEmpty ? '未选择提前提醒' : p.reviewDays.map((d) => '提前$d天').join('、')}',
          ),
      ]),
      panel([
        const Text('历史用药记录', style: sectionStyle),
        if (patient!.plans.isEmpty) const Text('暂无历史用药记录'),
        for (final p in patient!.plans.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.medications.map((m) => m.name).join('、')),
            subtitle: Text(dateLabel(p.created)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => HistoryPage(plan: p))),
          ),
      ]),
      OutlinedButton(
        onPressed: () => setState(() => tab = 2),
        child: const Text('＋ 添加新处方 / 药物'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('退出患者档案？'),
              content: const Text('用药记录会保留。退出后暂停此档案的系统提醒，再次登录后恢复。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('退出'),
                ),
              ],
            ),
          );
          if (ok != true) {
            return;
          }
          try {
            await notifications.cancel();
          } catch (_) {
            message('系统提醒取消失败，请检查手机通知设置');
            return;
          }
          if (mounted) {
            setState(() {
              patient = null;
              queue.clear();
              draft = [];
              photo = null;
              review = null;
              reviewDays = {};
            });
          }
        },
        child: const Text('退出登录'),
      ),
    ];
  }
}

const titleStyle = TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xff0f291e));
const sectionStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff0f291e));
Widget panel(List<Widget> children) => Card(
  margin: const EdgeInsets.only(bottom: 14),
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: w,
            ),
          )
          .toList(),
    ),
  ),
);

class LoginPage extends StatefulWidget {
  final PatientStore store;
  final Future<void> Function(Patient) onLogin;
  const LoginPage({super.key, required this.store, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      pin = TextEditingController(),
      repeat = TextEditingController();
  bool creating = false, busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    pin.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final p = creating
          ? await widget.store.create(name.text.trim(), pin.text)
          : await widget.store.login(name.text.trim(), pin.text);
      if (p == null) {
        throw StateError('未找到档案，请检查姓名和密码');
      }
      await widget.onLogin(p);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError ? e.message.toString() : '本地档案暂不可用，请重试',
        );
      }
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            child: Column(
              children: [
                panel([
                  const DogAvatar(),
                  const Text('护清晰视界 · 一路温柔陪伴', textAlign: TextAlign.center),
                ]),
                panel([
                  Text(
                    creating ? '创建患者档案' : '进入患者档案',
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const Text('姓名 + 6位数字密码', textAlign: TextAlign.center),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '姓名'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入姓名' : null,
                  ),
                  TextFormField(
                    controller: pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(labelText: '6位数字密码'),
                    validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                        ? null
                        : '密码必须为6位数字',
                  ),
                  if (creating)
                    TextFormField(
                      controller: repeat,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(labelText: '确认密码'),
                      validator: (v) => v == pin.text ? null : '两次密码不一致',
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? '请稍候…'
                          : creating
                          ? '创建患者档案'
                          : '进入我的档案',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            creating = !creating;
                            error = null;
                            pin.clear();
                            repeat.clear();
                            form.currentState?.reset();
                          }),
                    child: Text(creating ? '返回登录' : '创建患者档案'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const frequencies = [
  '每日1次',
  '每日2次',
  '每日3次',
  '每日4次',
  '每日5次',
  '每日6次',
  '每4小时1次',
  '每6小时1次',
  '每8小时1次',
];
int frequencyCount(String frequency) => frequency.startsWith('每日')
    ? int.parse(frequency.substring(2, 3))
    : 24 ~/ int.parse(frequency.substring(1, 2));

class MedicationEditor extends StatefulWidget {
  final Medication? medication;
  const MedicationEditor({super.key, this.medication});
  @override
  State<MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<MedicationEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      dose = TextEditingController(),
      days = TextEditingController();
  String? eye, frequency;
  late DateTime start;
  Set<String> times = {};
  String? error;
  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    name.text = m?.name ?? '';
    dose.text = m?.dose ?? '';
    days.text = m?.days.toString() ?? '';
    eye = m?.eye;
    frequency = m?.frequency;
    start = m?.start ?? day(DateTime.now());
    times = {...?m?.times};
  }

  @override
  void dispose() {
    name.dispose();
    dose.dispose();
    days.dispose();
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) {
      return;
    }
    if (eye == null || frequency == null || times.isEmpty) {
      setState(() => error = '请选择眼别、频次及提醒时间');
      return;
    }
    if (times.length != frequencyCount(frequency!)) {
      setState(() => error = '提醒时间数量应与${frequency!}一致，请核对');
      return;
    }
    if (frequency!.startsWith('每') && !frequency!.startsWith('每日')) {
      final hours = int.parse(frequency!.substring(1, 2));
      final minutes = times.map((t) {
        final p = t.split(':').map(int.parse).toList();
        return p[0] * 60 + p[1];
      }).toList()..sort();
      for (var i = 0; i < minutes.length; i++) {
        final delta =
            (minutes[(i + 1) % minutes.length] - minutes[i] + 1440) % 1440;
        if (delta != hours * 60) {
          setState(() => error = '所选时间不符合每$hours小时一次，请按医生指导核对');
          return;
        }
      }
    }
    Navigator.pop(
      context,
      Medication(
        id:
            widget.medication?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        eye: eye!,
        dose: dose.text.trim(),
        frequency: frequency!,
        start: start,
        days: int.parse(days.text),
        times: times.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.medication == null ? '手动添加药物' : '修改药物')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            panel([
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: '药品名称'),
                validator: (v) => (v ?? '').trim().isEmpty ? '请输入药品名称' : null,
              ),
              OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() => start = d);
                  }
                },
                child: Text('记录 / 开始日期：${dateLabel(start)}'),
              ),
              const Text('眼别'),
              Wrap(
                spacing: 8,
                children: ['左眼', '右眼', '双眼']
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e),
                        selected: eye == e,
                        onSelected: (_) => setState(() => eye = e),
                      ),
                    )
                    .toList(),
              ),
              TextFormField(
                controller: dose,
                decoration: const InputDecoration(labelText: '每次剂量（按医嘱填写）'),
                validator: (v) => (v ?? '').trim().isEmpty ? '请输入剂量' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: '用药频次'),
                items: frequencies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (f) => setState(() => frequency = f),
                validator: (v) => v == null ? '请选择频次' : null,
              ),
              TextFormField(
                controller: days,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '用药总天数'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 365
                      ? '请输入1–365天，较长疗程请分段确认'
                      : null;
                },
              ),
              const Text('提醒时间（可多选）'),
              Wrap(
                spacing: 8,
                children:
                    ({'08:00', '12:00', '17:00', ...times}.toList()..sort())
                        .map(
                          (t) => FilterChip(
                            label: Text(t),
                            selected: times.contains(t),
                            onSelected: (v) => setState(() {
                              v ? times.add(t) : times.remove(t);
                            }),
                          ),
                        )
                        .toList(),
              ),
              OutlinedButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                    builder: (c, child) => MediaQuery(
                      data: MediaQuery.of(
                        c,
                      ).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (t != null) {
                    setState(
                      () => times.add(
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                      ),
                    );
                  }
                },
                child: const Text('＋ 自定义时间'),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(onPressed: save, child: const Text('添加到用药计划')),
            ]),
          ],
        ),
      ),
    ),
  );
}

class HistoryPage extends StatelessWidget {
  final Plan plan;
  const HistoryPage({super.key, required this.plan});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('历史用药详情')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        panel([
          Text('确认日期：${dateLabel(plan.created)}'),
          if (plan.review != null) Text('复查日期：${dateLabel(plan.review!)}'),
          if (plan.photo != null)
            Image.file(
              File(plan.photo!),
              height: 220,
              errorBuilder: (_, _, _) => const Text('处方照片暂不可用'),
            ),
        ]),
        for (final m in plan.medications)
          panel([
            Text(m.name, style: titleStyle),
            Text('记录日期：${dateLabel(m.start)}'),
            Text('用药眼别：${m.eye}'),
            Text('每次剂量：${m.dose}'),
            Text('用药频次：${m.frequency}'),
            Text('总天数：${m.days}天'),
            Text('原始提醒：${m.times.join('、')}'),
            Text(
              '首日实际提醒：${eventsFor(plan, m.start).where((e) => e.medication?.id == m.id).map((e) => '${dateLabel(e.at)} ${clockLabel(e.at)}').join('、')}',
            ),
            OutlinedButton(
              onPressed: () => drugInfo(context, m.name),
              child: const Text('查看药物说明'),
            ),
          ]),
      ],
    ),
  );
}

Future<void> drugInfo(BuildContext context, String name) async {
  try {
    final info = await UnconnectedDrugCatalog().lookup(name);
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(name),
        content: Text(
          info?.description ??
              'Excel药物资料库尚未接入，当前没有可查询的药品说明。请核对药品随附说明书，并按照医生实际指导使用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('药物资料暂不可用，请查看药品随附说明书')));
    }
  }
}

class ReminderPage extends StatefulWidget {
  final String name;
  final ReminderEvent event;
  const ReminderPage({super.key, required this.name, required this.event});
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final tts = FlutterTts();
  bool speaking = false, failed = false;
  String get speech => widget.event.medication == null
      ? '${widget.name}，请记得复查，复查日期是${dateLabel(widget.event.plan.review!)}。'
      : '${widget.name}，到点儿啦，该点${widget.event.title}了，${widget.event.medication!.eye}，${widget.event.medication!.dose}。';
  @override
  void initState() {
    super.initState();
    tts.setErrorHandler((_) => fallback());
    WidgetsBinding.instance.addPostFrameCallback((_) => play());
  }

  void fallback() {
    if (mounted) {
      setState(() {
        failed = true;
        speaking = false;
      });
    }
  }

  Future<void> play() async {
    if (speaking) {
      return;
    }
    setState(() {
      failed = false;
      speaking = true;
    });
    try {
      await tts.setLanguage('zh-CN');
      await tts.setSpeechRate(0.4);
      await tts.awaitSpeakCompletion(true);
      final result = await tts
          .speak(speech)
          .timeout(const Duration(seconds: 45));
      if (result != 1) {
        fallback();
      }
    } catch (_) {
      try {
        await tts.stop();
      } catch (_) {
        /* Text and static dog remain available. */
      }
      fallback();
    }
    if (mounted) {
      setState(() => speaking = false);
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('温柔陪伴 · 到点提醒')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          panel([
            DogAvatar(animate: speaking && !failed, size: 132),
            Text(speech, style: titleStyle, textAlign: TextAlign.center),
            const Text('小狗 · 普通话语音', textAlign: TextAlign.center),
            Text(
              '${dateLabel(widget.event.at)} ${clockLabel(widget.event.at)}',
              textAlign: TextAlign.center,
            ),
            Text(widget.event.title, style: sectionStyle),
            Text(widget.event.body, style: sectionStyle),
            if (failed) const Text('请按上方文字核对本次提醒。'),
            OutlinedButton.icon(
              onPressed: speaking ? null : play,
              icon: const Icon(Icons.volume_up),
              label: const Text('播放语音'),
            ),
            if (widget.event.medication != null)
              OutlinedButton(
                onPressed: () => drugInfo(context, widget.event.title),
                child: const Text('查看药物说明'),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff059669),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('💧 ✅ 确认用药并一键打卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ]),
        ],
      ),
    ),
  );
}

/// Local animation resource slot. Replace the painter with a cached character
/// asset later; the static painter stays available without files or network.
class DogAvatar extends StatefulWidget {
  final bool animate;
  final double size;
  const DogAvatar({super.key, this.animate = false, this.size = 96});
  @override
  State<DogAvatar> createState() => _DogAvatarState();
}

class _DogAvatarState extends State<DogAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DogAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate) {
      controller.repeat(reverse: true);
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: '陪伴小狗',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: Container(
          width: widget.size,
          height: widget.size,
          color: Colors.black,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, _) {
              String asset = 'assets/dog_closed.png';
              if (widget.animate) {
                if (controller.value > 0.66) {
                  asset = 'assets/dog_open.png';
                } else if (controller.value > 0.33) {
                  asset = 'assets/dog_half.png';
                }
              }
              return Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => CustomPaint(
                  painter: DogPainter(controller.value),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class DogPainter extends CustomPainter {
  final double mouth;
  DogPainter(this.mouth);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final brown = Paint()..color = const Color(0xffa96938);
    final cream = Paint()..color = const Color(0xffffdca9);
    final ink = Paint()..color = const Color(0xff34281f);
    canvas.drawOval(const Rect.fromLTWH(5, 14, 26, 67), brown);
    canvas.drawOval(const Rect.fromLTWH(69, 14, 26, 67), brown);
    canvas.drawOval(const Rect.fromLTWH(20, 16, 60, 75), cream);
    canvas.drawCircle(const Offset(37, 46), 4, ink);
    canvas.drawCircle(const Offset(63, 46), 4, ink);
    canvas.drawOval(const Rect.fromLTWH(42, 57, 16, 10), ink);
    canvas.drawOval(Rect.fromLTWH(42, 71, 16, 3 + mouth * 11), ink);
    if (mouth > 0.3) {
      canvas.drawOval(
        Rect.fromLTWH(46, 75, 8, mouth * 8),
        Paint()..color = const Color(0xffef8e9b),
      );
    }
  }

  @override
  bool shouldRepaint(DogPainter oldDelegate) => oldDelegate.mouth != mouth;
}
