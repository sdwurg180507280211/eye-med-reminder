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
  Plan({
    required this.id,
    required this.created,
    required this.medications,
    this.review,
    this.reviewDays = const [],
    this.photo,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'created': created.toIso8601String(),
    'medications': medications.map((m) => m.toJson()).toList(),
    'review': review?.toIso8601String(),
    'reviewDays': reviewDays,
    'photo': photo,
  };
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    id: j['id'],
    created: DateTime.parse(j['created']),
    medications: (j['medications'] as List)
        .map((m) => Medication.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    review: j['review'] == null ? null : DateTime.parse(j['review']),
    reviewDays: List<int>.from(j['reviewDays']),
    photo: j['photo'],
  );
}

class Patient {
  final String id, name, salt, hash;
  final List<Plan> plans;
  Patient({
    required this.id,
    required this.name,
    required this.salt,
    required this.hash,
    required this.plans,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'salt': salt,
    'hash': hash,
    'plans': plans.map((p) => p.toJson()).toList(),
  };
  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: j['id'],
    name: j['name'],
    salt: j['salt'],
    hash: j['hash'],
    plans: (j['plans'] as List)
        .map((p) => Plan.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
  static List<Patient> decode(String raw) => (jsonDecode(raw) as List)
      .map((p) => Patient.fromJson(Map<String, dynamic>.from(p)))
      .toList();
}

class ReminderEvent {
  final DateTime at;
  final Plan plan;
  final Medication? medication;
  ReminderEvent(this.at, this.plan, this.medication);
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
        ),
      );
    }
  }
  if (plan.review != null) {
    for (final lead in plan.reviewDays) {
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
  final result = <ReminderEvent>[];
  for (var i = -1; i <= 365; i++) {
    final date = DateTime(now.year, now.month, now.day + i);
    result.addAll(
      patientEventsFor(patient, date).where((e) => e.at.isAfter(now)),
    );
    if (result.length >= limit) {
      break;
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result.take(limit).toList();
}
