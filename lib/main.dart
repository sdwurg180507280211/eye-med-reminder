import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'storage.dart';
import 'notifications.dart';
import 'drug_catalog.dart';
import 'design_system.dart';
import 'dog_avatar.dart';
import 'forms.dart';
export 'forms.dart'
    show LoginPage, MedicationEditor, frequencies, frequencyCount;
export 'dog_avatar.dart' show DogAvatar;

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
    theme: eyeMedTheme(),
    home: const PatientHome(),
  );
}

class PatientHome extends StatefulWidget {
  final PatientStore? store;
  final ReminderNotifications? notifications;
  final DateTime Function()? now;
  const PatientHome({super.key, this.store, this.notifications, this.now});
  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> with WidgetsBindingObserver {
  late final store = widget.store ?? PatientStore();
  late final notifications = widget.notifications ?? ReminderNotifications();
  DateTime now() => widget.now?.call() ?? DateTime.now();
  Patient? patient;
  bool loading = true, loadFailed = false;
  int tab = 0;
  String? pendingPayload;
  Timer? ticker;
  late DateTime lastTick = now();
  final seen = <String>{};
  final queue = <ReminderEvent>[];
  bool showingReminder = false;
  List<Medication> draft = [];
  DateTime? review;
  Set<int> reviewDays = {};
  String? photo;
  bool saving = false;
  bool changing = false,
      picking = false,
      refreshing = false,
      signingOut = false;
  int notificationRevision = 0;
  String notificationStatus = '正在准备系统提醒…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    boot();
  }

  Future<void> boot() async {
    ticker?.cancel();
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
    if (!loadFailed) {
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => checkDue());
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && patient != null && !signingOut) {
      checkDue();
      refreshNotifications();
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> refreshNotifications({bool requestPermission = false}) async {
    final current = patient;
    if (current == null || signingOut) {
      return;
    }
    final revision = ++notificationRevision;
    if (mounted) setState(() => refreshing = true);
    String status;
    try {
      if (!notifications.ready && requestPermission) {
        await notifications.initialize(openPayload);
      }
      // Initialization can finish after the patient has already signed out.
      if (!mounted || !identical(patient, current) || signingOut) return;
      if (!await notifications.schedule(
        current,
        requestPermission: requestPermission,
      )) {
        status = notifications.ready
            ? '尚未允许系统通知。请在手机设置中开启通知，再点“重新检查”。'
            : '系统提醒暂不可用，请点“重新检查”重试。';
      } else {
        final until = notifications.scheduledUntil;
        status = until == null
            ? '暂无后续提醒。'
            : '已安排 ${notifications.scheduledCount} 条提醒，至 ${dateLabel(until)} ${clockLabel(until)}。请在截止前打开应用续排。${notifications.exact ? '' : '精确闹钟未授权，通知可能延迟。'}';
      }
    } catch (_) {
      status = '系统提醒暂未安排成功，请重新检查通知权限。';
    }
    if (mounted &&
        patient?.id == current.id &&
        revision == notificationRevision) {
      setState(() {
        notificationStatus = status;
        refreshing = false;
      });
    }
  }

  void openPayload(String payload) {
    if (patient == null || signingOut) {
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
          if (e.plan.remindersPaused || patient!.isCompleted(e)) {
            message('这次提醒已暂停或已记录，请在今日用药中查看。');
            return;
          }
          if (queue.any((queued) => queued.key == e.key) ||
              (showingReminder && seen.contains(e.key))) {
            return;
          }
          queue.add(e);
          showNextReminder();
          return;
        }
      }
    }
  }

  void checkDue() {
    final currentTime = now();
    if (patient != null &&
        !signingOut &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      final since =
          lastTick.isBefore(currentTime.subtract(const Duration(minutes: 5)))
          ? currentTime.subtract(const Duration(minutes: 5))
          : lastTick;
      {
        for (final date in [
          DateTime(currentTime.year, currentTime.month, currentTime.day - 1),
          day(currentTime),
        ]) {
          for (final e in patientEventsFor(patient!, date)) {
            if (e.at.isAfter(since) &&
                !e.at.isAfter(currentTime) &&
                !patient!.isCompleted(e) &&
                seen.add(e.key)) {
              queue.add(e);
            }
          }
        }
      }
      showNextReminder();
    }
    if (mounted &&
        patient != null &&
        (lastTick.minute != currentTime.minute ||
            day(lastTick) != day(currentTime))) {
      setState(() {});
    }
    lastTick = currentTime;
  }

  Future<void> showNextReminder() async {
    if (showingReminder ||
        queue.isEmpty ||
        patient == null ||
        signingOut ||
        !mounted) {
      return;
    }
    showingReminder = true;
    queue.removeWhere((e) => e.plan.remindersPaused || patient!.isCompleted(e));
    if (queue.isEmpty) {
      showingReminder = false;
      return;
    }
    final event = queue.removeAt(0);
    seen.add(event.key);
    final wasHomeVisible = ModalRoute.of(context)?.isCurrent ?? false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReminderPage(
          name: patient!.name,
          event: event,
          onTaken: event.medication == null
              ? null
              : () => recordDose(event, true),
        ),
      ),
    );
    if (mounted && wasHomeVisible) {
      setState(() => tab = 0);
    }
    showingReminder = false;
    showNextReminder();
  }

  Future<void> signedIn(Patient p) async {
    setState(() {
      patient = p;
      tab = 0;
      draft = [];
      review = null;
      reviewDays = {};
      photo = null;
    });
    lastTick = now();
    seen.clear();
    if (pendingPayload != null) {
      final payload = pendingPayload!;
      pendingPayload = null;
      openPayload(payload);
    }
    await refreshNotifications(requestPermission: true);
  }

  Future<void> editMedication([int? index]) async {
    if (saving || changing || picking || patient == null) return;
    final patientId = patient!.id;
    final original = index == null ? null : draft[index];
    final m = await Navigator.of(context).push<Medication>(
      MaterialPageRoute(builder: (_) => MedicationEditor(medication: original)),
    );
    if (m != null &&
        mounted &&
        patient?.id == patientId &&
        !saving &&
        !changing) {
      final currentIndex = original == null
          ? -1
          : draft.indexWhere((item) => item.id == original.id);
      if (original != null && currentIndex < 0) {
        message('草稿已发生变化，请重新添加或修改这项药物。');
        return;
      }
      setState(() {
        if (index == null) {
          draft.add(m);
        } else {
          draft[currentIndex] = m;
        }
        tab = 1;
      });
    }
  }

  Future<void> pick(ImageSource source) async {
    if (picking || saving || changing || patient == null) return;
    final patientId = patient!.id;
    setState(() => picking = true);
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
        '${dir.path}/rx_${patientId}_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      if (mounted && patient?.id == patientId) {
        final previous = photo;
        setState(() => photo = saved.path);
        await removeUnusedPhoto(previous);
      } else {
        await removeUnusedPhoto(saved.path);
      }
    } catch (_) {
      message('未能获取照片，请检查相机或相册权限，也可以手动添加药物。');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> removeUnusedPhoto(String? path) async {
    if (path == null ||
        store.patients.any((p) => p.plans.any((plan) => plan.photo == path))) {
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // An unused photo must never prevent saving or editing a plan.
    }
  }

  Future<void> clearDraft() async {
    if (saving || changing || picking) return;
    final ok = await ask(
      '清空待确认草稿？',
      '这会清空本次录入的药物、照片与复查日期。已保存的用药计划仍保留。',
      '清空草稿',
    );
    if (!ok || !mounted) return;
    final previous = photo;
    setState(() {
      draft = [];
      photo = null;
      review = null;
      reviewDays = {};
    });
    await removeUnusedPhoto(previous);
  }

  Future<bool> ask(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> recordDose(ReminderEvent event, bool completed) async {
    if (changing || saving || patient == null) return false;
    if (completed && event.at.isAfter(now())) {
      message('这次提醒尚未到时间，请按医嘱用药后再记录。');
      return false;
    }
    final confirmed = await ask(
      completed ? '确认已用药？' : '撤销这次记录？',
      '${event.title}\n${dateLabel(event.at)} ${clockLabel(event.at)} · ${event.body}\n\n${completed ? '请确认你已按医嘱完成这次用药。此操作用于记录实际用药情况。' : '撤销后，这次用药将恢复为待记录。'}',
      completed ? '确认记录' : '撤销记录',
    );
    if (!confirmed || !mounted || patient == null) return false;
    setState(() => changing = true);
    try {
      await store.setDoseCompleted(patient!, event, completed, now: now());
      if (!mounted) return true;
      if (completed) {
        queue.removeWhere((e) => e.occurrenceKey == event.occurrenceKey);
      }
      setState(() {});
      message(completed ? '已记录本次用药' : '已撤销本次用药记录');
      await refreshNotifications();
      return true;
    } catch (_) {
      message('记录保存失败，请重试。');
      return false;
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> togglePlan(Plan plan) async {
    if (changing || saving || patient == null) return;
    final paused = !plan.remindersPaused;
    if (!paused &&
        plan.medications.any(
          (m) => patient!.plans
              .where((other) => other != plan && !other.remindersPaused)
              .expand((other) => other.medications)
              .any((old) => medicationsOverlap(m, old)),
        )) {
      message('已有相同药物在重叠疗程、眼别和时间提醒。请先核对其他计划，再恢复这份计划。');
      return;
    }
    final confirmed = await ask(
      paused ? '暂停这份计划的提醒？' : '恢复这份计划的提醒？',
      paused
          ? '该计划的用药与复查通知会暂停，处方和用药记录仍保留。是否继续用药请按医生指导决定。'
          : '将按当前疗程安排这份计划的后续用药与复查提醒。',
      paused ? '暂停提醒' : '恢复提醒',
    );
    if (!confirmed || !mounted || patient == null) return;
    setState(() => changing = true);
    try {
      await store.setPlanPaused(patient!, plan, paused);
      queue.removeWhere((e) => e.plan.remindersPaused);
      if (mounted) setState(() {});
      await refreshNotifications();
      message(paused ? '该计划的提醒已暂停' : '该计划的提醒已恢复');
    } catch (_) {
      message('计划状态保存失败，请重试。');
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  bool medicationsOverlap(Medication a, Medication b) {
    final aEnd = DateTime(a.start.year, a.start.month, a.start.day + a.days);
    final bEnd = DateTime(b.start.year, b.start.month, b.start.day + b.days);
    final eyesOverlap = a.eye == b.eye || a.eye == '双眼' || b.eye == '双眼';
    return a.name.trim() == b.name.trim() &&
        eyesOverlap &&
        a.start.isBefore(bEnd) &&
        b.start.isBefore(aEnd) &&
        a.times.any(b.times.contains);
  }

  List<String> draftTimeConflicts() {
    final currentTime = now();
    final previewPlan = Plan(
      id: '__draft_preview__',
      created: currentTime,
      medications: draft,
    );
    final preview = Patient(
      id: patient!.id,
      name: patient!.name,
      salt: '',
      hash: '',
      plans: [...patient!.plans, previewPlan],
    );
    final dates = <DateTime>{};
    for (final medication in draft) {
      for (var offset = 0; offset < medication.days; offset++) {
        final date = DateTime(
          medication.start.year,
          medication.start.month,
          medication.start.day + offset,
        );
        // A dose from either adjacent prescription day can share an actual
        // time with a dose staggered across midnight.
        for (var adjacent = -1; adjacent <= 1; adjacent++) {
          dates.add(DateTime(date.year, date.month, date.day + adjacent));
        }
      }
    }
    final groups = <DateTime, List<ReminderEvent>>{};
    for (final date in dates) {
      for (final event in patientEventsFor(preview, date)) {
        if (event.medication != null && event.at.isAfter(currentTime)) {
          groups.putIfAbsent(event.at, () => []).add(event);
        }
      }
    }
    final conflicts = <String>[];
    final actualTimes = groups.keys.toList()..sort();
    for (final at in actualTimes) {
      final events = groups[at]!;
      if (events.length > 1 &&
          events.any((event) => event.plan == previewPlan)) {
        conflicts.add(
          '${dateLabel(at)} ${clockLabel(at)}：${events.map((event) => event.title).join('、')}',
        );
        if (conflicts.length == 3) return conflicts;
      }
    }
    return conflicts;
  }

  Future<void> confirm() async {
    if (saving || changing || picking) {
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
    final checked = patient!.plans
        .where((p) => !p.remindersPaused)
        .expand((p) => p.medications)
        .toList();
    for (final m in draft) {
      if (checked.any((old) => medicationsOverlap(m, old))) {
        message('已有同名药物在重叠疗程、相同眼别和时间使用，请核对，避免重复提醒');
        return;
      }
      checked.add(m);
    }
    final conflicts = draftTimeConflicts();
    if (conflicts.isNotEmpty &&
        !await ask(
          '有实际提醒时间重叠',
          '${conflicts.join('\n')}\n\n请核对这些时间是否符合医嘱。系统会保留你确认的时间安排。',
          '已核对，继续保存',
        )) {
      return;
    }
    if (!mounted || patient == null) return;
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
      appBar: AppBar(
        title: Text(['今日用药', '用药计划', '添加处方'][tab]),
        actions: [
          IconButton(
            tooltip: '退出患者档案',
            onPressed: changing || saving || picking ? null : signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              onRefresh: () => refreshNotifications(),
              child: ListView(
                key: PageStorageKey('patient-tab-$tab'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: tab == 0
                    ? mine()
                    : tab == 1
                    ? plansView()
                    : capture(),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: saving || changing || picking
            ? null
            : (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: '用药计划',
          ),
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
      const Icon(
        Icons.add_a_photo_outlined,
        size: 42,
        color: Color(0xff1764d9),
      ),
      const Text('把医嘱整理成提醒', style: titleStyle),
      const Text('拍下处方便于核对，再逐项填写药物、剂量与时间。也可以直接手动录入。'),
    ]),
    panel([
      FilledButton.icon(
        onPressed: picking ? null : () => pick(ImageSource.camera),
        icon: const Icon(Icons.camera_alt),
        label: const Text('拍摄处方'),
      ),
      OutlinedButton.icon(
        onPressed: picking ? null : () => pick(ImageSource.gallery),
        icon: const Icon(Icons.photo),
        label: const Text('从相册选择'),
      ),
      if (photo != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(photo!),
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('照片暂不可用'),
          ),
        ),
        const Text('照片已保留，请对照照片手动核对医嘱。'),
        TextButton.icon(
          onPressed: picking
              ? null
              : () async {
                  final previous = photo;
                  setState(() => photo = null);
                  await removeUnusedPhoto(previous);
                },
          icon: const Icon(Icons.delete_outline),
          label: const Text('移除照片'),
        ),
      ],
      if (picking) const LinearProgressIndicator(),
      OutlinedButton.icon(
        onPressed: saving || changing || picking
            ? null
            : () => editMedication(),
        icon: const Icon(Icons.edit_note),
        label: const Text('手动添加药物'),
      ),
    ]),
    if (draft.isNotEmpty)
      panel([
        Text('草稿中已有 ${draft.length} 种药物', style: sectionStyle),
        Text(draft.map((m) => m.name).join('、')),
        FilledButton(
          onPressed: () => setState(() => tab = 1),
          child: const Text('核对并确认计划'),
        ),
      ]),
    const Padding(
      padding: EdgeInsets.all(8),
      child: Text('处方照片和档案保存在本机。确认计划前，请核对每一项医嘱。'),
    ),
  ];
  List<Widget> draftPlan() => [
    panel([
      Text('待确认 · ${draft.length} 种药物', style: titleStyle),
      const Text('请按照医生实际指导核对。识别不到的内容请自行填写，不根据药物常规用法自动补齐。'),
      TextButton(
        onPressed: saving || changing ? null : clearDraft,
        child: const Text('清空草稿'),
      ),
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
        onPressed: saving || changing || picking
            ? null
            : () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate:
                      review == null ||
                          review!.isBefore(day(now())) ||
                          review!.isAfter(now().add(const Duration(days: 365)))
                      ? day(now())
                      : review!,
                  firstDate: day(now()),
                  lastDate: now().add(const Duration(days: 365)),
                );
                if (d != null && mounted && !saving && !changing) {
                  setState(() => review = d);
                }
              },
        child: Text(review == null ? '选择复查日期（可不填）' : dateLabel(review!)),
      ),
      if (review != null)
        TextButton(
          onPressed: saving || changing || picking
              ? null
              : () => setState(() {
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
                onSelected: review == null || saving || changing || picking
                    ? null
                    : (v) => setState(() {
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
        Text('第${i + 1}种 · ${draft[i].name}', style: sectionStyle),
        Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: '上移 ${draft[i].name}',
              onPressed: saving || changing || picking || i == 0
                  ? null
                  : () => setState(() {
                      final m = draft.removeAt(i);
                      draft.insert(i - 1, m);
                    }),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: '下移 ${draft[i].name}',
              onPressed: saving || changing || picking || i == draft.length - 1
                  ? null
                  : () => setState(() {
                      final m = draft.removeAt(i);
                      draft.insert(i + 1, m);
                    }),
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
        Text(
          '${draft[i].eye} · ${draft[i].dose} · ${draft[i].frequency} · ${draft[i].days}天',
        ),
        Text('开始日期：${dateLabel(draft[i].start)}'),
        Text('原始时间：${draft[i].times.join('、')}'),
        Text(
          '实际时间：${previewTimes(i)}',
          style: const TextStyle(color: Color(0xff2675d6)),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: saving || changing || picking
                  ? null
                  : () => editMedication(i),
              child: const Text('修改'),
            ),
            TextButton(
              onPressed: () => drugInfo(context, draft[i].name),
              child: const Text('药物说明'),
            ),
            TextButton(
              onPressed: saving || changing || picking
                  ? null
                  : () => setState(() => draft.removeAt(i)),
              child: const Text('删除'),
            ),
          ],
        ),
      ]),
    OutlinedButton(
      onPressed: saving || changing || picking ? null : () => editMedication(),
      child: const Text('＋ 手动新增用药'),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('同一提醒时间的药物按上方顺序错开10分钟。实际时间可能因疗程重叠情况变化；若医生另有指定，以医生指导为准。'),
    ),
    FilledButton(
      onPressed: saving || changing || draft.isEmpty ? null : confirm,
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

  Widget statusTag(String text, {bool positive = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: positive ? const Color(0xffe9f6ef) : const Color(0xffeaf2ff),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: positive ? const Color(0xff216444) : const Color(0xff235caa),
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget notificationPanel() => panel([
    Row(
      children: [
        Icon(
          notifications.permissionGranted == true
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
          color: const Color(0xff1764d9),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('系统提醒', style: sectionStyle)),
      ],
    ),
    Text(notificationStatus),
    const Text(
      '后台收到通知后，点开即可查看本次用药并播放语音。',
      style: TextStyle(color: Color(0xff536579)),
    ),
    OutlinedButton.icon(
      onPressed: refreshing || changing || saving
          ? null
          : () => refreshNotifications(requestPermission: true),
      icon: refreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(refreshing ? '正在检查…' : '重新检查'),
    ),
  ]);

  List<Widget> mine() {
    final currentTime = now();
    final today = todayEvents(
      patient!,
      currentTime,
    ).where((e) => e.medication != null).toList();
    final completed = today.where(patient!.isCompleted).length;
    final nextEvents = upcoming(patient!, currentTime, limit: 1);
    final next = nextEvents.isEmpty ? null : nextEvents.first;
    final pausedCount = patient!.plans.where((p) => p.remindersPaused).length;
    final reviews =
        patient!.plans
            .where(
              (p) =>
                  !p.remindersPaused &&
                  p.review != null &&
                  !day(p.review!).isBefore(day(currentTime)),
            )
            .toList()
          ..sort((a, b) => a.review!.compareTo(b.review!));
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${patient!.name}，您好', style: titleStyle),
                  const SizedBox(height: 6),
                  Text(
                    '${dateLabel(currentTime)} · ${['周一', '周二', '周三', '周四', '周五', '周六', '周日'][currentTime.weekday - 1]}',
                    style: const TextStyle(color: Color(0xff536579)),
                  ),
                ],
              ),
            ),
            const DogAvatar(size: 64),
          ],
        ),
      ),
      Card(
        color: const Color(0xffe8f1ff),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '下一次提醒',
                style: TextStyle(
                  color: Color(0xff235caa),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                next == null ? '暂无后续提醒' : clockLabel(next.at),
                style: TextStyle(
                  fontSize: next == null ? 26 : 42,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff174e9b),
                ),
              ),
              if (next != null) ...[
                Text(
                  day(next.at) == day(currentTime) ? '今天' : dateLabel(next.at),
                  style: const TextStyle(color: Color(0xff536579)),
                ),
                const SizedBox(height: 12),
                Text(next.title, style: sectionStyle),
                Text(next.body),
              ] else
                const Text('添加处方后，系统会按你确认的时间安排提醒。'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() => tab = next == null ? 2 : 1),
                icon: Icon(
                  next == null ? Icons.add : Icons.medication_outlined,
                ),
                label: Text(next == null ? '添加用药计划' : '查看用药计划'),
              ),
            ],
          ),
        ),
      ),
      if (pausedCount > 0)
        panel([
          Text('$pausedCount 份计划已暂停提醒', style: sectionStyle),
          TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('管理已暂停计划'),
          ),
        ]),
      panel([
        const Text('今天的用药', style: sectionStyle),
        Text(
          today.isEmpty ? '今天暂无用药提醒' : '共 ${today.length} 次 · 已记录 $completed 次',
        ),
        if (today.isNotEmpty) ...[
          Semantics(
            label: '今日用药记录进度',
            value: '$completed / ${today.length}',
            child: LinearProgressIndicator(
              value: completed / today.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Text(
            '“已记录”由你自行确认，时间经过不会自动记录用药。',
            style: TextStyle(fontSize: 14, color: Color(0xff536579)),
          ),
        ] else
          const Text('可在用药计划中查看疗程、提醒状态与历史处方。'),
      ]),
      for (final event in today) doseCard(event),
      if (reviews.isNotEmpty)
        panel([
          const Text('接下来的复查', style: sectionStyle),
          for (final plan in reviews)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(dateLabel(plan.review!)),
              subtitle: Text(
                plan.reviewDays.isEmpty
                    ? '未设置提前提醒'
                    : plan.reviewDays.map((d) => '提前$d天').join('、'),
              ),
              onTap: () => openPlan(plan),
            ),
        ]),
      notificationPanel(),
    ];
  }

  Widget doseCard(ReminderEvent event) {
    final done = patient!.isCompleted(event);
    final future = event.at.isAfter(now());
    final recordedAt = patient!.doseCompletions[event.occurrenceKey];
    return KeyedSubtree(
      key: ValueKey('dose-${event.occurrenceKey}'),
      child: panel([
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              clockLabel(event.at),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xff174e9b),
              ),
            ),
            statusTag(
              done
                  ? '已记录用药'
                  : future
                  ? '待提醒'
                  : '待记录',
              positive: done,
            ),
          ],
        ),
        Text(event.title, style: sectionStyle),
        Text(event.body, style: const TextStyle(fontSize: 18)),
        if (recordedAt != null)
          Text(
            '记录时间 ${clockLabel(recordedAt)}',
            style: const TextStyle(color: Color(0xff536579)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (done)
              TextButton.icon(
                onPressed: changing || saving
                    ? null
                    : () => recordDose(event, false),
                icon: const Icon(Icons.undo_rounded),
                label: const Text('撤销记录'),
              )
            else
              OutlinedButton.icon(
                onPressed: changing || saving || future
                    ? null
                    : () => recordDose(event, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('记录已用药'),
              ),
            TextButton(
              onPressed: () => drugInfo(context, event.title),
              child: const Text('药物说明'),
            ),
          ],
        ),
      ]),
    );
  }

  void openPlan(Plan plan) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HistoryPage(plan: plan, patient: patient),
    ),
  );

  String planStatus(Plan plan) {
    if (plan.remindersPaused) return '提醒已暂停';
    final today = day(now());
    if (plan.medications.any(
      (m) =>
          !today.isBefore(day(m.start)) &&
          today.isBefore(
            DateTime(m.start.year, m.start.month, m.start.day + m.days),
          ),
    )) {
      return '疗程中';
    }
    if (plan.medications.any((m) => day(m.start).isAfter(today))) return '尚未开始';
    if (plan.review != null && !day(plan.review!).isBefore(today)) {
      return '等待复查';
    }
    return '疗程已结束';
  }

  List<Widget> plansView() => [
    if (draft.isNotEmpty || photo != null || review != null)
      ...draftPlan()
    else
      panel([
        const Text('按医嘱管理每份计划', style: titleStyle),
        const Text('已确认的处方会保留在这里。你可以查看详情，也可以暂停或恢复这份计划的提醒。'),
        FilledButton.icon(
          onPressed: () => setState(() => tab = 2),
          icon: const Icon(Icons.add),
          label: const Text('添加新处方'),
        ),
      ]),
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('已保存计划 · ${patient!.plans.length} 份', style: sectionStyle),
    ),
    if (patient!.plans.isEmpty)
      panel([
        const Icon(
          Icons.assignment_outlined,
          size: 42,
          color: Color(0xff8ca4bd),
        ),
        const Text('还没有已保存的计划', style: sectionStyle),
        const Text('手动录入药物并确认后，就可以在这里管理提醒。'),
      ]),
    for (final plan in patient!.plans.reversed)
      panel([
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            statusTag(planStatus(plan), positive: planStatus(plan) == '疗程中'),
            Text(
              '确认于 ${dateLabel(plan.created)}',
              style: const TextStyle(color: Color(0xff536579)),
            ),
          ],
        ),
        Text(
          plan.medications.map((m) => m.name).join('、'),
          style: sectionStyle,
        ),
        for (final medication in plan.medications)
          Text(
            '${medication.eye} · ${medication.frequency} · ${dateLabel(medication.start)} 起 ${medication.days} 天',
          ),
        if (plan.review != null) Text('复查 ${dateLabel(plan.review!)}'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => openPlan(plan),
              icon: const Icon(Icons.description_outlined),
              label: const Text('查看处方'),
            ),
            TextButton.icon(
              onPressed: changing || saving ? null : () => togglePlan(plan),
              icon: Icon(
                plan.remindersPaused
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
              ),
              label: Text(plan.remindersPaused ? '恢复提醒' : '暂停提醒'),
            ),
          ],
        ),
      ]),
  ];

  Future<void> signOut() async {
    if (changing || saving || picking) return;
    final confirmed = await ask(
      '退出患者档案？',
      '已保存的用药记录会保留，未确认的草稿会清空。退出后暂停此档案的系统提醒，再次登录后恢复。',
      '退出',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      changing = true;
      signingOut = true;
    });
    try {
      await notifications.cancel();
      final previousPhoto = photo;
      notificationRevision++;
      if (mounted) {
        setState(() {
          patient = null;
          queue.clear();
          draft = [];
          photo = null;
          review = null;
          reviewDays = {};
          refreshing = false;
        });
      }
      await removeUnusedPhoto(previousPhoto);
    } catch (_) {
      message('系统提醒取消失败，请重试后再退出。');
    } finally {
      if (mounted) {
        setState(() {
          changing = false;
          signingOut = false;
        });
      }
    }
  }
}

class HistoryPage extends StatelessWidget {
  final Plan plan;
  final Patient? patient;
  const HistoryPage({super.key, required this.plan, this.patient});

  List<MapEntry<DateTime, DateTime>> recordsFor(Medication medication) {
    final prefix = '${plan.id}|${medication.id}|';
    final records = <MapEntry<DateTime, DateTime>>[];
    for (final record
        in patient?.doseCompletions.entries ?? <MapEntry<String, DateTime>>[]) {
      if (!record.key.startsWith(prefix)) continue;
      final originalAt = DateTime.tryParse(record.key.substring(prefix.length));
      if (originalAt != null) records.add(MapEntry(originalAt, record.value));
    }
    records.sort((a, b) => b.key.compareTo(a.key));
    return records;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('处方与用药详情')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              panel([
                Text(
                  plan.remindersPaused ? '这份计划的提醒已暂停' : '这份计划的提醒未暂停',
                  style: sectionStyle,
                ),
                Text('确认日期：${dateLabel(plan.created)}'),
                if (plan.review != null)
                  Text('复查日期：${dateLabel(plan.review!)}'),
                if (plan.photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(plan.photo!),
                      height: 220,
                      errorBuilder: (_, _, _) => const Text('处方照片暂不可用'),
                    ),
                  ),
              ]),
              for (final medication in plan.medications)
                panel([
                  Text(medication.name, style: titleStyle),
                  Text('开始日期：${dateLabel(medication.start)}'),
                  Text('用药眼别：${medication.eye}'),
                  Text('每次剂量：${medication.dose}'),
                  Text('用药频次：${medication.frequency}'),
                  Text('总天数：${medication.days}天'),
                  Text('原始提醒：${medication.times.join('、')}'),
                  const Text('同时间药物会按确认顺序错开，当天实际提醒时间见“今日”。'),
                  OutlinedButton(
                    onPressed: () => drugInfo(context, medication.name),
                    child: const Text('查看药物说明'),
                  ),
                  if (patient != null) ...[
                    Text(
                      '已记录 ${recordsFor(medication).length} 次用药',
                      style: sectionStyle,
                    ),
                    for (final record in recordsFor(medication))
                      Text(
                        '${dateLabel(record.key)} 原始 ${clockLabel(record.key)}\n记录于 ${dateLabel(record.value)} ${clockLabel(record.value)}',
                      ),
                  ],
                ]),
            ],
          ),
        ),
      ),
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
        scrollable: true,
        title: Text(name),
        content: Text(
          info?.description ?? '暂无该药物的可查询资料。请查看药品随附说明书，或向医生、药师咨询，并按医嘱使用。',
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
  final Future<bool> Function()? onTaken;
  const ReminderPage({
    super.key,
    required this.name,
    required this.event,
    this.onTaken,
  });
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final tts = FlutterTts();
  bool speaking = false, failed = false, recording = false;
  int speechRevision = 0;
  String get speech => widget.event.medication == null
      ? '${widget.name}，请记得复查，复查日期是${dateLabel(widget.event.plan.review!)}。'
      : '${widget.name}，到点儿啦，该点${widget.event.title}了，${widget.event.medication!.eye}，${widget.event.medication!.dose}。';
  @override
  void initState() {
    super.initState();
    tts.setErrorHandler((_) => fallback());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) play();
    });
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
    final revision = ++speechRevision;
    try {
      await tts.setLanguage('zh-CN');
      await tts.setSpeechRate(0.4);
      await tts.awaitSpeakCompletion(true);
      final result = await tts
          .speak(speech)
          .timeout(const Duration(seconds: 45));
      if (!mounted || revision != speechRevision) return;
      if (result != 1) {
        fallback();
      }
    } catch (_) {
      if (!mounted || revision != speechRevision) return;
      try {
        await tts.stop();
      } catch (_) {
        /* Text and static dog remain available. */
      }
      fallback();
    }
    if (mounted && revision == speechRevision) {
      setState(() => speaking = false);
    }
  }

  @override
  void dispose() {
    speechRevision++;
    tts.stop().catchError((_) => null);
    super.dispose();
  }

  Future<void> stopSpeech() async {
    speechRevision++;
    try {
      await tts.stop();
    } catch (_) {
      /* Keep the written reminder available. */
    }
    if (mounted) setState(() => speaking = false);
  }

  Future<void> taken() async {
    if (recording || widget.onTaken == null) return;
    setState(() => recording = true);
    try {
      final saved = await widget.onTaken!();
      if (saved && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => recording = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !recording,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.event.medication == null ? '复查提醒' : '用药提醒'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                panel([
                  Text(
                    clockLabel(widget.event.at),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff174e9b),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(dateLabel(widget.event.at), textAlign: TextAlign.center),
                  DogAvatar(animate: speaking && !failed, size: 112),
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    widget.event.body,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    speech,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xff536579)),
                  ),
                  if (failed) const Text('请按上方文字核对本次提醒。'),
                  OutlinedButton.icon(
                    onPressed: speaking ? stopSpeech : play,
                    icon: Icon(
                      speaking ? Icons.stop_circle_outlined : Icons.volume_up,
                    ),
                    label: Text(speaking ? '停止语音' : '播放语音'),
                  ),
                  if (widget.event.medication != null)
                    OutlinedButton(
                      onPressed: () => drugInfo(context, widget.event.title),
                      child: const Text('查看药物说明'),
                    ),
                  if (widget.onTaken != null)
                    FilledButton.icon(
                      onPressed: recording ? null : taken,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(recording ? '正在保存…' : '我已按医嘱用药'),
                    ),
                  OutlinedButton(
                    onPressed: recording ? null : () => Navigator.pop(context),
                    child: const Text('结束提醒'),
                  ),
                  if (widget.event.medication != null)
                    const Text(
                      '结束提醒仅关闭页面。实际用药后，可单独记录本次用药。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xff536579)),
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
