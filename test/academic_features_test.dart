import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_tugas_kuliah/models/academic_schedule.dart';
import 'package:catatan_tugas_kuliah/models/subject.dart';
import 'package:catatan_tugas_kuliah/models/task_item.dart';
import 'package:catatan_tugas_kuliah/models/task_attachment.dart';
import 'package:catatan_tugas_kuliah/services/storage_service.dart';
import 'package:catatan_tugas_kuliah/services/reminder_plan.dart';
import 'package:catatan_tugas_kuliah/screens/dashboard_screen.dart';
import 'package:catatan_tugas_kuliah/screens/task_detail_screen.dart';
import 'package:catatan_tugas_kuliah/screens/widgets/add_subject_dialog.dart';
import 'package:catatan_tugas_kuliah/screens/widgets/schedule_fields.dart';
import 'regression_test.dart' show loadProvider, showApp, snapshot, loadFonts;

MentariSchedule mentari({int weeks = 1}) => MentariSchedule(
  firstStart: DateTime(2026, 10, 5, 8),
  firstDeadline: DateTime(2026, 10, 11, 23, 59),
  until: DateTime(2026, 12, 21),
  intervalWeeks: weeks,
  url: 'https://example.com/kelas',
  reminderMinutes: [1440, 60],
);
Subject course({String id = 's', int weeks = 1}) => Subject(
  id: id,
  name: 'Pemrograman Mobile',
  colorValue: 0xFF5177B8,
  semester: '2026/2027 Ganjil',
  mentari: mentari(weeks: weeks),
  tasks: [
    TaskItem(
      id: 't_$id',
      subjectId: id,
      title: 'Presentasi aplikasi',
      deadline: '2026-10-26',
      deadlineMinutes: 13 * 60,
      kind: 'presentation',
      status: 'doing',
      attachments: [
        TaskAttachment(
          id: 'link_$id',
          name: 'Materi',
          url: 'https://example.com/materi',
        ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  test(
    'weekly and fortnightly dates preserve start/deadline anchors and end date',
    () {
      for (final weeks in [1, 2]) {
        final events = mentari(
          weeks: weeks,
        ).occurrences(from: DateTime(2026, 10, 1), to: DateTime(2027));
        expect(events[1].start, DateTime(2026, 10, 5 + weeks * 7, 8));
        expect(events[1].deadline, DateTime(2026, 10, 11 + weeks * 7, 23, 59));
        expect(
          events.last.start.isAfter(DateTime(2026, 12, 21, 23, 59)),
          false,
        );
        expect(
          events.last.deadline.isAfter(DateTime(2026, 12, 21, 23, 59)),
          false,
        );
        final roundTrip = MentariSchedule.fromJson(
          mentari(weeks: weeks).toJson(),
        );
        expect(roundTrip.toJson(), mentari(weeks: weeks).toJson());
      }
    },
  );
  test(
    'UTS and UAS skip overlapping windows without shifting subsequent cycles',
    () {
      final breaks = [
        ExamBreak(
          name: 'UTS',
          start: DateTime(2026, 10, 19),
          end: DateTime(2026, 10, 25),
        ),
        ExamBreak(
          name: 'UAS',
          start: DateTime(2026, 12, 14),
          end: DateTime(2026, 12, 20),
        ),
      ];
      for (final weeks in [1, 2]) {
        final events = mentari(weeks: weeks).occurrences(
          from: DateTime(2026, 10, 1),
          to: DateTime(2027),
          breaks: breaks,
        );
        expect(
          events.any((e) => breaks.any((b) => b.overlaps(e.start, e.deadline))),
          false,
        );
        expect(events.any((e) => e.start == DateTime(2026, 11, 2, 8)), true);
        expect(events.any((e) => e.start == DateTime(2026, 10, 19, 8)), false);
      }
      final overlap = mentari().occurrences(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 12),
        breaks: [
          ExamBreak(
            name: 'UTS',
            start: DateTime(2026, 10, 10),
            end: DateTime(2026, 10, 12),
          ),
        ],
      );
      expect(overlap.any((e) => e.start.day == 5), false);
    },
  );
  test(
    'reminder plan omits completed, archived, exam-period, and past reminders',
    () {
      final s = course().copyWith(
        examBreaks: [
          ExamBreak(
            name: 'UTS',
            start: DateTime(2026, 10, 19),
            end: DateTime(2026, 10, 25),
          ),
        ],
      );
      final now = DateTime(2026, 10, 5);
      final plan = planReminders([s], now);
      expect(plan.every((r) => r.at.isAfter(now)), true);
      expect(plan.any((r) => r.key.contains('mentari:s:2026-10-19')), false);
      expect(plan.first.at, DateTime(2026, 10, 5, 8));
      expect(
        plan.any(
          (r) =>
              r.key == 'mentari:s:2026-10-05:60' &&
              r.at == DateTime(2026, 10, 11, 22, 59),
        ),
        true,
      );
      final done = s.copyWith(
        mentari: s.mentari!.withCompletion('2026-10-05', true),
        tasks: [s.tasks.first.copyWith(isDone: true)],
      );
      final after = planReminders([done], now);
      expect(
        after.any(
          (r) => r.key.startsWith('task:') || r.key.contains('2026-10-05'),
        ),
        false,
      );
      expect(planReminders([s.copyWith(isArchived: true)], now), isEmpty);
    },
  );
  test(
    'semester exam edits persist atomically and newly added subjects inherit periods',
    () async {
      final provider = await loadProvider([
        course(),
        course(id: 's2').copyWith(semester: 'Semester lain'),
      ]);
      addTearDown(provider.dispose);
      final b = ExamBreak(
        name: 'UTS',
        start: DateTime(2026, 10, 19),
        end: DateTime(2026, 10, 25),
      );
      await provider.setExamBreaks('2026/2027 Ganjil', [b]);
      expect(provider.subjects.first.examBreaks.single.name, 'UTS');
      expect(provider.subjects[1].examBreaks, isEmpty);
      await provider.addSubject(
        'Basis Data',
        0xFF123456,
        semester: '2026/2027 Ganjil',
        mentari: mentari(weeks: 2),
      );
      expect(provider.subjects.first.examBreaks.single.toJson(), b.toJson());
      provider.setSemester('Semester lain');
      expect(provider.visibleSubjects.single.id, 's2');
      expect(provider.getAllTasksWithSubject().single.subject.id, 's2');
      await provider.setMentariDone('s', '2026-10-05', true);
      expect(provider.getSubjectById('s')!.mentari!.completed, ['2026-10-05']);
      await expectLater(
        provider.setMentariDone('s', '2026-10-19', true),
        throwsFormatException,
      );
      final imported = StorageService().importFromJson(provider.exportData())!;
      expect(imported.first.examBreaks.single.toJson(), b.toJson());
      expect(imported.firstWhere((s) => s.id == 's').mentari!.completed, [
        '2026-10-05',
      ]);
      await provider.deleteSubject('s2');
      expect(provider.semester, isNull);
      expect(provider.visibleSubjects.length, 2);
    },
  );
  test(
    'recurring completion creates one future instance and rollback cannot duplicate it',
    () async {
      final now = DateTime.now();
      final task = TaskItem(
        id: 'repeat',
        subjectId: 's',
        title: 'Laporan mingguan',
        deadline: dateKey(shiftDays(now, 1)),
        repeatDays: 7,
        subTasks: [SubTask(id: 'step', title: 'Tulis', isDone: true)],
      );
      final provider = await loadProvider([
        course().copyWith(tasks: [task]),
      ]);
      addTearDown(provider.dispose);
      await provider.setTaskStatus('s', 'repeat', 'ready');
      expect(provider.getSubjectById('s')!.tasks.length, 1);
      await provider.setTaskStatus('s', 'repeat', 'submitted');
      var tasks = provider.getSubjectById('s')!.tasks;
      expect(tasks.length, 2);
      expect(tasks.last.deadline, dateKey(shiftDays(now, 8)));
      expect(tasks.last.isDone, false);
      expect(tasks.last.subTasks.single.isDone, false);
      await provider.toggleTaskStatus('s', 'repeat');
      await provider.toggleTaskStatus('s', 'repeat');
      tasks = provider.getSubjectById('s')!.tasks;
      expect(tasks.length, 2);
      await provider.addTask(
        's',
        'Tugas harian terkumpul',
        deadline: dateKey(shiftDays(now, 1)),
        details: {'status': 'submitted', 'repeatDays': 1},
      );
      tasks = provider.getSubjectById('s')!.tasks;
      expect(tasks.length, 4);
      expect(tasks.last.deadline, dateKey(shiftDays(now, 2)));
      expect(tasks.last.status, 'todo');
    },
  );
  test(
    'invalid new fields and attachment paths cannot replace existing data',
    () async {
      final provider = await loadProvider([course()]);
      addTearDown(provider.dispose);
      final baseline = provider.exportData();
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (s) => s['mentari']['intervalWeeks'] = 0,
        (s) => s['mentari']['url'] = 'javascript:alert(1)',
        (s) => s['mentari']['firstDeadline'] = '2020-01-01T00:00:00',
        (s) => s['tasks'][0]['status'] = 'invalid',
        (s) => s['tasks'][0]['attachments'][0]['id'] = '../../file',
        (s) => s['tasks'][0]['deadlineMinutes'] = 1440,
      ]) {
        final decoded = jsonDecode(baseline) as List;
        mutate(decoded[0]);
        expect(await provider.importData(jsonEncode(decoded)), false);
        expect(provider.exportData(), baseline);
      }
    },
  );
  test(
    'v1 records migrate without losing task completion, notes or original reminder time',
    () {
      final s = course().toJson();
      s.remove('mentari');
      s.remove('semester');
      s.remove('examBreaks');
      final t = s['tasks'][0] as Map<String, dynamic>;
      for (final key in [
        'status',
        'deadlineMinutes',
        'reminderMinutes',
        'kind',
        'description',
        'repeatDays',
        'seriesId',
        'attachments',
      ]) {
        t.remove(key);
      }
      t['isDone'] = true;
      final parsed = StorageService().importFromJson(jsonEncode([s]))!.single;
      expect(parsed.tasks.single.status, 'submitted');
      expect(parsed.mentari, isNull);
      final pending = parsed.copyWith(
        tasks: [parsed.tasks.single.copyWith(isDone: false)],
      );
      expect(
        planReminders([pending], DateTime(2026, 10, 1)).single.at,
        DateTime(2026, 10, 26, 8),
      );
    },
  );
  testWidgets(
    'Mentari form exposes weekly, fortnightly, deadline and semester fields',
    (tester) async {
      final provider = await loadProvider([course()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider);
      AddSubjectDialog.show(
        tester.element(find.byType(DashboardScreen)),
        initialSubject: course(),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(MentariEditor));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Setiap 2 minggu'));
      await tester.tap(find.text('Setiap 2 minggu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('berulang setiap 14 hari'), findsOneWidget);
      expect(find.textContaining('Deadline pertemuan pertama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'v2 home, calendar, task detail and Mentari fit large text and render previews',
    (tester) async {
      final provider = await loadProvider([
        course(),
        course(
          id: 'b',
          weeks: 2,
        ).copyWith(name: 'Arsitektur dan Organisasi Komputer'),
      ]);
      addTearDown(provider.dispose);
      final key = GlobalKey();
      await showApp(
        tester,
        provider,
        capture: key,
        home: DashboardScreen(provider: provider),
      );
      await snapshot(tester, key, 'v2_beranda');
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      await snapshot(tester, key, 'v2_kalender');
      for (final size in [const Size(320, 700), const Size(393, 852)]) {
        await showApp(
          tester,
          provider,
          size: size,
          scale: 2,
          home: TaskDetailScreen(
            provider: provider,
            subjectId: 's',
            taskId: 't_s',
          ),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await showApp(
        tester,
        provider,
        capture: key,
        home: TaskDetailScreen(
          provider: provider,
          subjectId: 's',
          taskId: 't_s',
        ),
      );
      await snapshot(tester, key, 'v2_detail_tugas');
    },
  );
}
