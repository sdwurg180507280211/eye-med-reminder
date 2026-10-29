import 'package:flutter_test/flutter_test.dart';
import 'package:eye_med_reminder/models.dart';

Medication med(
  String id,
  List<String> times, {
  DateTime? start,
  int days = 2,
}) => Medication(
  id: id,
  name: '药$id',
  eye: '双眼',
  dose: '每眼1滴',
  frequency: '每日${times.length}次',
  start: start ?? DateTime(2026, 10, 4),
  days: days,
  times: times,
);
Plan plan(
  List<Medication> meds, {
  DateTime? review,
  List<int> reviewDays = const [],
}) => Plan(
  id: 'p',
  created: DateTime(2026, 10, 4),
  medications: meds,
  review: review,
  reviewDays: reviewDays,
);

void main() {
  test('simultaneous medicines in different prescriptions also stagger', () {
    final a = plan([
      med('a', ['08:00']),
    ]);
    final b = Plan(
      id: 'b',
      created: a.created,
      medications: [
        med('b', ['08:00']),
      ],
    );
    final patient = Patient(
      id: 'p',
      name: '王',
      salt: '',
      hash: '',
      plans: [a, b],
    );
    expect(patientEventsFor(patient, a.created).map((e) => clockLabel(e.at)), [
      '08:00',
      '08:10',
    ]);
  });
  test(
    'shared times follow medicine order without shifting unshared times',
    () {
      final p = plan([
        med('a', ['08:00', '12:00']),
        med('b', ['08:00', '17:00']),
        med('c', ['08:00']),
      ]);
      expect(eventsFor(p, DateTime(2026, 10, 4)).map((e) => clockLabel(e.at)), [
        '08:00',
        '08:10',
        '08:20',
        '12:00',
        '17:00',
      ]);
      final reordered = plan([p.medications[1], p.medications[0]]);
      expect(
        eventsFor(reordered, DateTime(2026, 10, 4)).first.medication!.id,
        'b',
      );
    },
  );
  test('ten minute offsets crossing midnight retain the next date', () {
    final p = plan([
      med('a', ['23:55']),
      med('b', ['23:55']),
    ]);
    final result = eventsFor(p, DateTime(2026, 10, 4));
    expect(result.last.at, DateTime(2026, 10, 5, 0, 5));
  });
  test(
    'inclusive start and exclusive course end; inactive drugs do not shift others',
    () {
      final p = plan([
        med('a', ['08:00'], days: 1),
        med('b', ['08:00']),
      ]);
      expect(eventsFor(p, DateTime(2026, 10, 3)), isEmpty);
      expect(
        eventsFor(p, DateTime(2026, 10, 5)).single.at,
        DateTime(2026, 10, 5, 8),
      );
      expect(eventsFor(p, DateTime(2026, 10, 6)), isEmpty);
    },
  );
  test('review reminders only use selected lead days', () {
    final p = plan([], review: DateTime(2026, 10, 10), reviewDays: [3, 1]);
    expect(
      eventsFor(p, DateTime(2026, 10, 7)).single.at,
      DateTime(2026, 10, 7, 8),
    );
    expect(eventsFor(p, DateTime(2026, 10, 8)), isEmpty);
    expect(eventsFor(p, DateTime(2026, 10, 9)).single.medication, isNull);
  });
  test(
    'notification horizon stays bounded and includes prior-day rollover',
    () {
      final p = plan([
        med('a', ['23:55'], days: 365),
        med('b', ['23:55'], days: 365),
      ]);
      final patient = Patient(
        id: 'x',
        name: '王',
        salt: '',
        hash: '',
        plans: [p],
      );
      final result = upcoming(patient, DateTime(2026, 10, 5));
      expect(result.length, 60);
      expect(result.first.at, DateTime(2026, 10, 5, 0, 5));
      expect(result.every((e) => e.at.isAfter(DateTime(2026, 10, 5))), isTrue);
    },
  );
  test('the next reminder includes earlier doses from the next base day', () {
    final p = plan([
      med('a', ['23:55'], days: 1),
      med('b', ['23:55'], days: 1),
      med('early', ['00:01'], start: DateTime(2026, 10, 5), days: 1),
    ]);
    final patient = Patient(id: 'x', name: '王', salt: '', hash: '', plans: [p]);
    final next = upcoming(patient, DateTime(2026, 10, 5), limit: 1);
    expect(next.single.medication!.id, 'early');
    expect(next.single.at, DateTime(2026, 10, 5, 0, 1));
  });
  test('a full reminder queue still considers earlier next-base-day doses', () {
    final p = plan([
      for (var i = 0; i <= 60; i++) med('late-$i', ['23:55'], days: 1),
      med('early', ['00:01'], start: DateTime(2026, 10, 5), days: 1),
    ]);
    final patient = Patient(id: 'x', name: '王', salt: '', hash: '', plans: [p]);
    final result = upcoming(patient, DateTime(2026, 10, 5));
    expect(result, hasLength(60));
    expect(result.first.medication!.id, 'early');
    expect(result.last.medication!.id, 'late-59');
    expect(result.last.at, DateTime(2026, 10, 5, 9, 45));
    expect(result.any((event) => event.medication!.id == 'late-60'), isFalse);
  });
  test('serialization preserves patient and plan history', () {
    final p = plan(
      [
        med('a', ['08:00']),
      ],
      review: DateTime(2026, 10, 10),
      reviewDays: [2],
    );
    final restored = Plan.fromJson(p.toJson());
    expect(restored.medications.single.toJson(), p.medications.single.toJson());
    expect(restored.reviewDays, [2]);
    expect(restored.review, p.review);
  });

  test('old profiles load with active plans and empty completion history', () {
    final p = plan([
      med('a', ['08:00']),
    ]);
    final raw = p.toJson()..remove('remindersPaused');
    final patient = Patient.fromJson({
      'id': 'legacy',
      'name': '王',
      'salt': '',
      'hash': '',
      'plans': [raw],
    });
    expect(patient.plans.single.remindersPaused, isFalse);
    expect(patient.doseCompletions, isEmpty);
    expect(eventsFor(patient.plans.single, p.created), hasLength(1));
  });

  test('pausing a peer plan cannot change a dose completion identity', () {
    final a = plan([
      med('a', ['08:00']),
    ]);
    final b = Plan(
      id: 'b',
      created: a.created,
      medications: [
        med('b', ['08:00']),
      ],
    );
    final patient = Patient(
      id: 'patient',
      name: '王',
      salt: '',
      hash: '',
      plans: [a, b],
    );
    final shifted = patientEventsFor(patient, a.created).last;
    patient.doseCompletions[shifted.occurrenceKey] = DateTime(
      2026,
      10,
      4,
      8,
      15,
    );
    a.remindersPaused = true;
    final unshifted = patientEventsFor(patient, a.created).single;
    expect(shifted.at, DateTime(2026, 10, 4, 8, 10));
    expect(unshifted.at, DateTime(2026, 10, 4, 8));
    expect(unshifted.occurrenceKey, shifted.occurrenceKey);
    expect(unshifted.key, isNot(shifted.key));
    expect(patient.isCompleted(unshifted), isTrue);
  });

  test('a peer course ending leaves the same original dose key', () {
    final target = med('b', ['08:00']);
    final before = plan([
      med('a', ['08:00'], days: 2),
      target,
    ]);
    final after = plan([
      med('a', ['08:00'], days: 1),
      target,
    ]);
    final shifted = eventsFor(before, DateTime(2026, 10, 5)).last;
    final unshifted = eventsFor(after, DateTime(2026, 10, 5)).single;
    expect(shifted.occurrenceKey, unshifted.occurrenceKey);
    expect(shifted.at, DateTime(2026, 10, 5, 8, 10));
    expect(unshifted.at, DateTime(2026, 10, 5, 8));
  });

  test('cross-midnight identity retains the original prescription day', () {
    final p = plan([
      med('a', ['23:55']),
      med('b', ['23:55']),
    ]);
    final event = eventsFor(p, p.created).last;
    expect(event.at, DateTime(2026, 10, 5, 0, 5));
    expect(event.originalAt, DateTime(2026, 10, 4, 23, 55));
    expect(event.occurrenceKey, 'p|b|2026-10-04T23:55:00.000');
    expect(event.key, 'p|b|2026-10-05T00:05:00.000');
  });

  test(
    'today includes rollover and completed doses only on the actual day',
    () {
      final p = plan([
        med('a', ['23:55']),
        med('b', ['23:55']),
      ]);
      final patient = Patient(
        id: 'x',
        name: '王',
        salt: '',
        hash: '',
        plans: [p],
      );
      final rollover = eventsFor(p, p.created).last;
      patient.doseCompletions[rollover.occurrenceKey] = DateTime(
        2026,
        10,
        5,
        0,
        6,
      );
      final today = todayEvents(patient, DateTime(2026, 10, 5, 1));
      expect(today.map((e) => e.at), [
        DateTime(2026, 10, 5, 0, 5),
        DateTime(2026, 10, 5, 23, 55),
      ]);
      expect(patient.isCompleted(today.first), isTrue);
      expect(
        upcoming(
          patient,
          DateTime(2026, 10, 5),
        ).any((e) => e.occurrenceKey == rollover.occurrenceKey),
        isFalse,
      );
    },
  );

  test(
    'paused plans omit medicine and review events while retaining history',
    () {
      final p = plan(
        [
          med('a', ['08:00']),
        ],
        review: DateTime(2026, 10, 5),
        reviewDays: [1],
      );
      final patient = Patient(
        id: 'x',
        name: '王',
        salt: '',
        hash: '',
        plans: [p],
      );
      final dose = eventsFor(
        p,
        p.created,
      ).firstWhere((e) => e.medication != null);
      patient.doseCompletions[dose.occurrenceKey] = DateTime(2026, 10, 4, 8, 1);
      p.remindersPaused = true;
      expect(eventsFor(p, p.created), isEmpty);
      expect(upcoming(patient, DateTime(2026, 10, 4)), isEmpty);
      final restored = Patient.fromJson(patient.toJson());
      expect(restored.plans.single.remindersPaused, isTrue);
      expect(restored.doseCompletions, patient.doseCompletions);
      expect(restored.plans.single.medications, hasLength(1));
      expect(restored.plans.single.review, p.review);
    },
  );
}
