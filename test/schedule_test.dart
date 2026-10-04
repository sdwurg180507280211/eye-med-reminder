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
}
