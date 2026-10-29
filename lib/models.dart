import 'dart:convert';

String dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String clockLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

class Medication {
  final String id, name, eye, dose, frequency;
  final DateTime start;
  final int days;
  final List<String> times;
  Medication({
    required this.id,
    required this.name,
    required this.eye,
    required this.dose,
    required this.frequency,
    required this.start,
    required this.days,
    required this.times,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'eye': eye,
    'dose': dose,
    'frequency': frequency,
    'start': dateLabel(start),
    'days': days,
    'times': times,
  };
  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    id: j['id'],
    name: j['name'],
    eye: j['eye'],
    dose: j['dose'],
    frequency: j['frequency'],
    start: DateTime.parse(j['start']),
    days: j['days'],
    times: List<String>.from(j['times']),
  );
}

class Plan {
  final String id;
  final DateTime created;
  final List<Medication> medications;
  final DateTime? review;
  final List<int> reviewDays;
  final String? photo;
  bool remindersPaused;
  Plan({
    required this.id,
    required this.created,
    required this.medications,
    this.review,
    this.reviewDays = const [],
    this.photo,
    this.remindersPaused = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'created': created.toIso8601String(),
    'medications': medications.map((m) => m.toJson()).toList(),
    'review': review?.toIso8601String(),
    'reviewDays': reviewDays,
    'photo': photo,
    'remindersPaused': remindersPaused,
  };
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    id: j['id'],
    created: DateTime.parse(j['created']),
    medications: (j['medications'] as List)
        .map((m) => Medication.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    review: j['review'] == null ? null : DateTime.parse(j['review']),
    reviewDays: List<int>.from(j['reviewDays'] ?? const []),
    photo: j['photo'],
    remindersPaused: j['remindersPaused'] == true,
  );
}

class Patient {
  final String id, name, salt, hash;
  final List<Plan> plans;
  final Map<String, DateTime> doseCompletions;
  Patient({
    required this.id,
    required this.name,
    required this.salt,
    required this.hash,
    required this.plans,
    Map<String, DateTime>? doseCompletions,
  }) : doseCompletions = Map.of(doseCompletions ?? const {});
  bool isCompleted(ReminderEvent event) =>
      event.medication != null &&
      doseCompletions.containsKey(event.occurrenceKey);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'salt': salt,
    'hash': hash,
    'plans': plans.map((p) => p.toJson()).toList(),
    'doseCompletions': doseCompletions.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
  };
  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: j['id'],
    name: j['name'],
    salt: j['salt'],
    hash: j['hash'],
    plans: (j['plans'] as List)
        .map((p) => Plan.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
    doseCompletions: Map<String, dynamic>.from(
      j['doseCompletions'] ?? const {},
    ).map((key, value) => MapEntry(key, DateTime.parse(value as String))),
  );
  static List<Patient> decode(String raw) => (jsonDecode(raw) as List)
      .map((p) => Patient.fromJson(Map<String, dynamic>.from(p)))
      .toList();
}

class ReminderEvent {
  final DateTime at;
  final Plan plan;
  final Medication? medication;
  final DateTime originalAt;
  ReminderEvent(this.at, this.plan, this.medication, {DateTime? originalAt})
    : originalAt = originalAt ?? at;
  // Completion belongs to the prescribed dose, even if another course is
  // paused or ends and its ten-minute stagger subsequently changes.
  String get occurrenceKey =>
      '${plan.id}|${medication?.id ?? 'review'}|${originalAt.toIso8601String()}';
  String get key =>
      '${plan.id}|${medication?.id ?? 'review'}|${at.toIso8601String()}';
  String get title => medication?.name ?? '复查提醒';
  String get body => medication == null
      ? '复查日期：${dateLabel(plan.review!)}'
      : '${medication!.eye} · ${medication!.dose}';
}

// Order applies only to medicines sharing the same original time and active day.
// Keep the date when a ten-minute offset crosses midnight.
List<ReminderEvent> eventsFor(
  Plan plan,
  DateTime date, {
  Map<String, int>? sharedCounts,
}) {
  if (plan.remindersPaused) {
    return [];
  }
  final counts = sharedCounts ?? <String, int>{};
  final result = <ReminderEvent>[];
  for (final m in plan.medications) {
    final start = day(m.start);
    final base = day(date);
    if (base.isBefore(start) ||
        !base.isBefore(DateTime(start.year, start.month, start.day + m.days))) {
      continue;
    }
    for (final time in m.times.toSet().toList()..sort()) {
      final parts = time.split(':').map(int.parse).toList();
      final offset = counts[time] ?? 0;
      counts[time] = offset + 1;
      result.add(
        ReminderEvent(
          DateTime(
            base.year,
            base.month,
            base.day,
            parts[0],
            parts[1] + 10 * offset,
          ),
          plan,
          m,
          originalAt: DateTime(
            base.year,
            base.month,
            base.day,
            parts[0],
            parts[1],
          ),
        ),
      );
    }
  }
  if (plan.review != null) {
    for (final lead in plan.reviewDays.toSet()) {
      final review = plan.review!;
      final at = DateTime(review.year, review.month, review.day - lead, 8);
      if (day(at) == day(date)) {
        result.add(ReminderEvent(at, plan, null));
      }
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}

List<ReminderEvent> patientEventsFor(Patient patient, DateTime date) {
  final counts = <String, int>{};
  final result = <ReminderEvent>[];
  for (final plan in patient.plans) {
    result.addAll(eventsFor(plan, date, sharedCounts: counts));
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}

List<ReminderEvent> upcoming(Patient patient, DateTime now, {int limit = 60}) {
  if (limit <= 0) {
    return [];
  }
  final result = <ReminderEvent>[];
  for (var i = -1; i <= 365; i++) {
    final date = DateTime(now.year, now.month, now.day + i);
    result.addAll(
      patientEventsFor(
        patient,
        date,
      ).where((e) => e.at.isAfter(now) && !patient.isCompleted(e)),
    );
    if (result.length >= limit) {
      result.sort((a, b) => a.at.compareTo(b.at));
      final nextBaseDay = DateTime(now.year, now.month, now.day + i + 1);
      // A late dose from this base day can stagger past the next day's early
      // doses. Stop only after later base days cannot precede our cutoff.
      if (nextBaseDay.isAfter(result[limit - 1].at)) {
        break;
      }
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result.take(limit).toList();
}

// Include doses from the previous prescription day that stagger past midnight.
// Completed doses remain visible here so the daily timeline retains history.
List<ReminderEvent> todayEvents(Patient patient, DateTime now) {
  final today = day(now);
  final result = [
    ...patientEventsFor(
      patient,
      DateTime(today.year, today.month, today.day - 1),
    ),
    ...patientEventsFor(patient, today),
  ].where((event) => day(event.at) == today).toList();
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}
