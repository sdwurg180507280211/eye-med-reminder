import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'storage.dart';
import 'design_system.dart';
import 'dog_avatar.dart';

class LoginPage extends StatefulWidget {
  final PatientStore store;
  final Future<void> Function(Patient) onLogin;
  const LoginPage({super.key, required this.store, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final pin = TextEditingController();
  final repeat = TextEditingController();
  bool creating = false, busy = false, hidePin = true, hideRepeat = true;
  String? error;

  @override
  void dispose() {
    name.dispose();
    pin.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    // Keyboard submission can arrive even after the button is disabled.
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final patient = creating
          ? await widget.store.create(name.text.trim(), pin.text)
          : await widget.store.login(name.text.trim(), pin.text);
      if (!mounted) return;
      if (patient == null) {
        throw StateError('姓名或密码不匹配，请核对；首次使用请创建患者档案');
      }
      await widget.onLogin(patient);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is StateError
              ? exception.message.toString()
              : '暂时无法读取或保存本地档案，请稍后重试',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void switchMode() {
    FocusScope.of(context).unfocus();
    form.currentState?.reset();
    setState(() {
      creating = !creating;
      error = null;
      pin.clear();
      repeat.clear();
      hidePin = hideRepeat = true;
    });
  }

  void clearError(String _) {
    if (error != null) setState(() => error = null);
  }

  Widget pinField({bool confirmation = false}) => TextFormField(
    key: ValueKey(confirmation ? 'repeat-pin' : 'login-pin'),
    controller: confirmation ? repeat : pin,
    enabled: !busy,
    obscureText: confirmation ? hideRepeat : hidePin,
    enableSuggestions: false,
    autocorrect: false,
    keyboardType: TextInputType.number,
    textInputAction: !confirmation && creating
        ? TextInputAction.next
        : TextInputAction.done,
    onFieldSubmitted: (_) {
      if (!confirmation && creating) {
        FocusScope.of(context).nextFocus();
      } else {
        submit();
      }
    },
    onChanged: clearError,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(
      labelText: confirmation ? '确认密码' : '6位数字密码',
      suffixIcon: IconButton(
        tooltip: (confirmation ? hideRepeat : hidePin) ? '显示密码' : '隐藏密码',
        onPressed: busy
            ? null
            : () => setState(() {
                if (confirmation) {
                  hideRepeat = !hideRepeat;
                } else {
                  hidePin = !hidePin;
                }
              }),
        icon: Icon(
          (confirmation ? hideRepeat : hidePin)
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: (value) => confirmation
        ? value == pin.text && RegExp(r'^\d{6}$').hasMatch(value ?? '')
              ? null
              : '两次密码不一致，请重新确认'
        : RegExp(r'^\d{6}$').hasMatch(value ?? '')
        ? null
        : '密码必须为6位数字',
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DogAvatar(size: 104),
                  const SizedBox(height: 12),
                  const Text(
                    '眼科用药提醒助手',
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '护清晰视界 · 一路温柔陪伴',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: eyeMedMuted),
                  ),
                  const SizedBox(height: 24),
                  panel([
                    Text(creating ? '创建患者档案' : '进入患者档案', style: sectionStyle),
                    Text(
                      creating ? '使用姓名和6位数字密码保护你的档案。' : '输入姓名和密码，继续查看用药计划。',
                      style: const TextStyle(color: eyeMedMuted),
                    ),
                    TextFormField(
                      key: const ValueKey('patient-name'),
                      controller: name,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      onChanged: clearError,
                      decoration: const InputDecoration(labelText: '姓名'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入姓名'
                          : null,
                    ),
                    pinField(),
                    if (creating) pinField(confirmation: true),
                    if (error != null) _FormError(error!),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy
                            ? '正在处理…'
                            : creating
                            ? '创建患者档案'
                            : '进入我的档案',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : switchMode,
                      child: Text(creating ? '返回登录' : '创建患者档案'),
                    ),
                  ]),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '档案保存在这台设备中，不上传到服务器。请记住姓名和密码；更换设备不会自动同步档案。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: eyeMedMuted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
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
  final name = TextEditingController();
  final dose = TextEditingController();
  final days = TextEditingController();
  String? eye, frequency;
  late DateTime start;
  late DateTime originalStart;
  Set<String> times = {};
  String? error;
  bool submitted = false, allowPop = false, confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    name.text = medication?.name ?? '';
    dose.text = medication?.dose ?? '';
    days.text = medication?.days.toString() ?? '';
    eye = medication?.eye;
    frequency = medication?.frequency;
    start = day(medication?.start ?? DateTime.now());
    originalStart = start;
    times = {...?medication?.times};
    name.addListener(fieldsChanged);
    dose.addListener(fieldsChanged);
    days.addListener(fieldsChanged);
  }

  bool get hasChanges {
    final medication = widget.medication;
    return name.text != (medication?.name ?? '') ||
        dose.text != (medication?.dose ?? '') ||
        days.text != (medication?.days.toString() ?? '') ||
        eye != medication?.eye ||
        frequency != medication?.frequency ||
        start != originalStart ||
        !setEquals(times, {...?medication?.times});
  }

  void fieldsChanged() {
    if (mounted) setState(() => error = null);
  }

  @override
  void dispose() {
    name.dispose();
    dose.dispose();
    days.dispose();
    super.dispose();
  }

  void close([Medication? medication]) {
    if (allowPop) return;
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(medication);
    });
  }

  Future<void> confirmDiscard() async {
    if (confirmingDiscard) return;
    confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('放弃未保存的修改？'),
        content: const Text('本次填写还没有保存。你可以继续编辑，或放弃修改后返回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    confirmingDiscard = false;
    if (mounted && discard == true) close();
  }

  void save() {
    if (allowPop) return;
    FocusScope.of(context).unfocus();
    setState(() {
      submitted = true;
      error = null;
    });
    final validFields = form.currentState!.validate();
    if (!validFields || eye == null) return;
    if (frequency == null || times.isEmpty) {
      setState(() => error = '请选择提醒时间，与医嘱频次对应');
      return;
    }
    if (times.length != frequencyCount(frequency!)) {
      setState(() => error = '提醒时间数量应与${frequency!}一致，请核对');
      return;
    }
    if (!frequency!.startsWith('每日')) {
      final hours = int.parse(frequency!.substring(1, 2));
      final minutes = times.map((time) {
        final parts = time.split(':').map(int.parse).toList();
        return parts[0] * 60 + parts[1];
      }).toList()..sort();
      for (var index = 0; index < minutes.length; index++) {
        final delta =
            (minutes[(index + 1) % minutes.length] - minutes[index] + 1440) %
            1440;
        if (delta != hours * 60) {
          setState(() => error = '所选时间不符合每$hours小时一次，请按医生指导核对');
          return;
        }
      }
    }
    close(
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

  Future<void> chooseDate() async {
    final today = day(DateTime.now());
    // Previously saved courses can fall outside the usual picker range.
    final first = start.isBefore(DateTime(2020)) ? start : DateTime(2020);
    final typicalLast = DateTime(today.year + 1, today.month, today.day);
    final last = start.isAfter(typicalLast) ? start : typicalLast;
    final selected = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
    );
    if (selected != null && mounted) {
      setState(() {
        start = selected;
        error = null;
      });
    }
  }

  Future<void> chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        times.add(
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
        );
        error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Medication>(
    canPop: allowPop || !hasChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) confirmDiscard();
    },
    child: Scaffold(
      appBar: AppBar(title: Text(widget.medication == null ? '添加药物' : '修改药物')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: form,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, right: 4, bottom: 16),
                      child: Text(
                        '请对照处方逐项填写。药品、剂量和时间都需由你确认。',
                        style: TextStyle(color: eyeMedMuted),
                      ),
                    ),
                    panel([
                      const _SectionHeading('药物信息', Icons.medication_outlined),
                      TextFormField(
                        key: const ValueKey('medication-name'),
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '药品名称'),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? '请输入药品名称' : null,
                      ),
                      const Text(
                        '用药眼别',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['左眼', '右眼', '双眼']
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value),
                                selected: eye == value,
                                onSelected: (_) => setState(() {
                                  eye = value;
                                  error = null;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      if (submitted && eye == null) const _FormError('请选择用药眼别'),
                      TextFormField(
                        key: const ValueKey('medication-dose'),
                        controller: dose,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '每次剂量',
                          helperText: '按医嘱原文填写，不预设滴数或用量',
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? '请输入剂量' : null,
                      ),
                    ]),
                    panel([
                      const _SectionHeading('疗程与频次', Icons.date_range_outlined),
                      OutlinedButton(
                        onPressed: chooseDate,
                        child: Text(
                          '疗程开始日期：${dateLabel(start)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('medication-frequency'),
                        initialValue: frequency,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '用药频次'),
                        items: frequencies
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          frequency = value;
                          error = null;
                        }),
                        validator: (value) => value == null ? '请选择频次' : null,
                      ),
                      TextFormField(
                        key: const ValueKey('medication-days'),
                        controller: days,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '用药总天数',
                          helperText: '支持1–365天，疗程以医生建议为准',
                        ),
                        validator: (value) {
                          final count = int.tryParse(value ?? '');
                          return count == null || count < 1 || count > 365
                              ? '请输入1–365天，较长疗程请分段确认'
                              : null;
                        },
                      ),
                    ]),
                    panel([
                      const _SectionHeading('提醒时间', Icons.schedule_outlined),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          frequency == null
                              ? '已选${times.length}个时间，请先选择用药频次'
                              : '已选${times.length}个时间 · 需要${frequencyCount(frequency!)}个',
                          style: const TextStyle(color: eyeMedMuted),
                        ),
                      ),
                      const Text(
                        '以下时间仅供选择，请按医嘱确认。',
                        style: TextStyle(color: eyeMedMuted, fontSize: 13),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            ({'08:00', '12:00', '17:00', ...times}.toList()
                                  ..sort())
                                .map(
                                  (time) => FilterChip(
                                    label: Text(time),
                                    selected: times.contains(time),
                                    onSelected: (selected) => setState(() {
                                      selected
                                          ? times.add(time)
                                          : times.remove(time);
                                      error = null;
                                    }),
                                  ),
                                )
                                .toList(),
                      ),
                      OutlinedButton(
                        onPressed: chooseTime,
                        child: const Text('＋ 自定义时间'),
                      ),
                      if (frequency != null && !frequency!.startsWith('每日'))
                        const Text(
                          '按小时间隔的频次需覆盖全天，间隔包含跨夜时间，请对照医嘱核对。',
                          style: TextStyle(color: eyeMedMuted, fontSize: 13),
                        ),
                      if (error != null) _FormError(error!),
                    ]),
                    FilledButton(
                      onPressed: save,
                      child: Text(
                        widget.medication == null ? '添加到用药计划' : '保存修改',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeading(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3, right: 10),
        child: Icon(icon, size: 22, color: eyeMedBlue),
      ),
      Expanded(child: Text(title, style: sectionStyle)),
    ],
  );
}

class _FormError extends StatelessWidget {
  final String message;
  const _FormError(this.message);
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.5),
    ),
  );
}
