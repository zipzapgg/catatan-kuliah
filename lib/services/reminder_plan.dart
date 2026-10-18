import 'dart:convert';
import '../models/subject.dart';
import '../models/academic_schedule.dart';
import '../models/tuition_payment.dart';

class PlannedReminder {
  final String key;
  final DateTime at;
  final String title;
  final String body;
  final String payload;
  const PlannedReminder(this.key, this.at, this.title, this.body, this.payload);
}

List<PlannedReminder> planReminders(
  List<Subject> subjects,
  DateTime now, {
  List<TuitionPayment> payments = const [],
}) {
  final result = <PlannedReminder>[];
  for (final subject in subjects.where((s) => !s.isArchived)) {
    for (final task in subject.tasks.where(
      (t) => !t.isDone && t.dueAt != null,
    )) {
      for (final minutes in task.reminderMinutes.toSet()) {
        final at = task.dueAt!.subtract(Duration(minutes: minutes));
        if (at.isAfter(now)) {
          result.add(
            PlannedReminder(
              'task:${task.id}:$minutes',
              at,
              '${subject.name} · ${TaskLabel.forMinutes(minutes)}',
              task.title,
              jsonEncode({'subject': subject.id, 'task': task.id}),
            ),
          );
        }
      }
    }
    final schedule = subject.mentari;
    if (schedule == null) continue;
    for (final occurrence in schedule.occurrences(
      from: now,
      to: shiftDays(schedule.until, 1),
      breaks: subject.examBreaks,
    )) {
      if (occurrence.isDone) continue;
      final payload = jsonEncode({
        'subject': subject.id,
        'mentari': occurrence.key,
      });
      if (occurrence.start.isAfter(now)) {
        result.add(
          PlannedReminder(
            'mentari:${subject.id}:${occurrence.key}:start',
            occurrence.start,
            'Mentari · ${subject.name}',
            'Pertemuan dibuka. Deadline ${dateKey(occurrence.deadline)} ${_clock(occurrence.deadline)}.',
            payload,
          ),
        );
      }
      for (final minutes in schedule.reminderMinutes.toSet()) {
        final at = occurrence.deadline.subtract(Duration(minutes: minutes));
        if (at.isBefore(occurrence.start) ||
            !at.isAfter(now) ||
            subject.examBreaks.any((b) => b.contains(at))) {
          continue;
        }
        result.add(
          PlannedReminder(
            'mentari:${subject.id}:${occurrence.key}:$minutes',
            at,
            'Mentari · ${TaskLabel.forMinutes(minutes)}',
            '${subject.name}: deadline ${_clock(occurrence.deadline)}.',
            payload,
          ),
        );
      }
    }
  }
  for (final payment in payments.where((p) => !p.isPaid && p.dueAt != null)) {
    for (final minutes in payment.reminderMinutes.toSet()) {
      final at = payment.dueAt!.subtract(Duration(minutes: minutes));
      if (at.isAfter(now)) {
        result.add(
          PlannedReminder(
            'payment:${payment.id}:$minutes',
            at,
            'Bayaran kuliah · ${TaskLabel.forMinutes(minutes)}',
            payment.title,
            jsonEncode({'payment': payment.id}),
          ),
        );
      }
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class TaskLabel {
  static String forMinutes(int minutes) => switch (minutes) {
    0 => 'Saat deadline',
    60 => '1 jam sebelum deadline',
    1440 => '1 hari sebelum deadline',
    4320 => '3 hari sebelum deadline',
    10080 => '7 hari sebelum deadline',
    _ => '$minutes menit sebelum deadline',
  };
}
