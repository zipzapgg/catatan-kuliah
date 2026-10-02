import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catatan_tugas_kuliah/models/subject.dart';
import 'package:catatan_tugas_kuliah/models/task_item.dart';
import 'package:catatan_tugas_kuliah/models/note_item.dart';
import 'package:catatan_tugas_kuliah/services/storage_service.dart';
import 'package:catatan_tugas_kuliah/providers/app_provider.dart';
import 'package:catatan_tugas_kuliah/utils/deadline_helper.dart';

void main() {
  group('Model Unit Tests', () {
    test('Subject progress calculation is accurate', () {
      final subject = Subject(
        id: 'sub_1',
        name: 'MANAJEMEN PROJEK',
        colorValue: 0xFF2563EB,
        tasks: [
          TaskItem(id: 't1', subjectId: 'sub_1', title: 'buat makalah', isDone: true),
          TaskItem(id: 't2', subjectId: 'sub_1', title: 'ppt', isDone: false),
        ],
        notes: [
          NoteItem(id: 'n1', subjectId: 'sub_1', content: 'catatan penting'),
        ],
      );

      expect(subject.totalTasks, 2);
      expect(subject.completedTasks, 1);
      expect(subject.pendingTasks, 1);
      expect(subject.progressPercentage, 0.5);
      expect(subject.progressText, '1/2 tugas selesai');
      expect(subject.notes.length, 1);
    });

    test('TaskItem serialization to/from JSON works correctly', () {
      final task = TaskItem(
        id: 't_test',
        subjectId: 'sub_test',
        title: 'buat makalah template kp',
        isDone: false,
        deadline: 'Sebelum UTS',
      );

      final json = task.toJson();
      final fromJson = TaskItem.fromJson(json);

      expect(fromJson.id, task.id);
      expect(fromJson.subjectId, task.subjectId);
      expect(fromJson.title, task.title);
      expect(fromJson.isDone, false);
      expect(fromJson.deadline, 'Sebelum UTS');
    });

    test('NoteItem serialization to/from JSON preserves multiline content', () {
      final note = NoteItem(
        id: 'n_test',
        subjectId: 'sub_test',
        content: 'makalah nya pasti nge print banyak,\nppt harus ngejelasin sesuai ketentuan',
      );

      final json = note.toJson();
      final fromJson = NoteItem.fromJson(json);

      expect(fromJson.id, note.id);
      expect(fromJson.content, contains('\n'));
      expect(fromJson.content, note.content);
    });

    test('Corrupted saved data is surfaced instead of treated as empty', () async {
      SharedPreferences.setMockInitialValues({
        'is_first_launch_done': true,
        'saved_subjects_data': '{not valid json',
      });

      await expectLater(StorageService().loadSubjects(), throwsFormatException);
    });

    test('Existing data receives missing sample subjects without duplicates', () async {
      final existingSubject = Subject(
        id: 'existing_subject',
        name: 'MANAJEMEN PROJEK',
        colorValue: 0xFF2563EB,
      );
      SharedPreferences.setMockInitialValues({
        'is_first_launch_done': true,
        'saved_subjects_data': jsonEncode([existingSubject.toJson()]),
      });

      final subjects = await StorageService().loadSubjects();

      expect(subjects.where((subject) => subject.name == 'MANAJEMEN PROJEK'), hasLength(1));
      expect(
        subjects.map((subject) => subject.name),
        containsAll(['ARSITEKTUR DAN ORGANISASI KOMPUTER', 'KECAKAPAN ANTAR PERSONAL']),
      );
    });

    test('TaskItem priority defaults to normal and serializes correctly', () {
      final task = TaskItem(
        id: 't_prio',
        subjectId: 'sub_1',
        title: 'Tugas Penting',
        priority: 'high',
      );

      final json = task.toJson();
      expect(json['priority'], 'high');

      final fromJson = TaskItem.fromJson(json);
      expect(fromJson.priority, 'high');

      final defaultTask = TaskItem(
        id: 't_def',
        subjectId: 'sub_1',
        title: 'Tugas Biasa',
      );
      expect(defaultTask.priority, 'normal');
    });

    test('formatSubjectForSharing produces structured text for WhatsApp', () {
      final subject = Subject(
        id: 'sub_share',
        name: 'PEMROGRAMAN MOBILE',
        colorValue: 0xFF2563EB,
        tasks: [
          TaskItem(id: 't1', subjectId: 'sub_share', title: 'Bikin UI Flutter', isDone: true),
          TaskItem(
            id: 't2',
            subjectId: 'sub_share',
            title: 'Presentasi',
            isDone: false,
            deadline: 'Besok',
            priority: 'high',
          ),
        ],
        notes: [
          NoteItem(id: 'n1', subjectId: 'sub_share', content: 'Demo harus di HP fisik'),
        ],
      );

      final appProvider = AppProvider();
      final text = appProvider.formatSubjectForSharing(subject);

      expect(text, contains('PEMROGRAMAN MOBILE'));
      expect(text, contains('1/2 tugas selesai'));
      expect(text, contains('✅ [SELESAI] Bikin UI Flutter'));
      expect(text, contains('⬜ [BELUM] Presentasi (Deadline: Besok) 🔴 [PENTING]'));
      expect(text, contains('Demo harus di HP fisik'));
    });

    test('Subject schedule fields serialize and deserialize accurately', () {
      final subject = Subject(
        id: 'sub_sched',
        name: 'BASIS DATA',
        colorValue: 0xFF059669,
        scheduleDay: 'Senin',
        scheduleTime: '10:00 - 12:30',
        room: 'Lab Database',
        lecturer: 'Drs. Slamet, M.T.',
      );

      final json = subject.toJson();
      expect(json['scheduleDay'], 'Senin');
      expect(json['scheduleTime'], '10:00 - 12:30');
      expect(json['room'], 'Lab Database');
      expect(json['lecturer'], 'Drs. Slamet, M.T.');

      final fromJson = Subject.fromJson(json);
      expect(fromJson.scheduleDay, 'Senin');
      expect(fromJson.scheduleTime, '10:00 - 12:30');
      expect(fromJson.room, 'Lab Database');
      expect(fromJson.lecturer, 'Drs. Slamet, M.T.');
      expect(fromJson.hasSchedule, true);
    });

    test('SubTask serialization and TaskItem subtask helpers work properly', () {
      final subtasks = [
        SubTask(id: 'st_1', title: 'Cari referensi jurnal', isDone: true),
        SubTask(id: 'st_2', title: 'Bikin bab 1 pendahuluan', isDone: false),
        SubTask(id: 'st_3', title: 'Review dosen pembimbing', isDone: false),
      ];

      final task = TaskItem(
        id: 'task_complex',
        subjectId: 'sub_1',
        title: 'Skripsi Bab 1',
        subTasks: subtasks,
      );

      expect(task.hasSubTasks, true);
      expect(task.totalSubTasks, 3);
      expect(task.completedSubTasks, 1);

      final json = task.toJson();
      expect(json['subTasks'], isA<List>());
      expect((json['subTasks'] as List).length, 3);

      final fromJson = TaskItem.fromJson(json);
      expect(fromJson.hasSubTasks, true);
      expect(fromJson.totalSubTasks, 3);
      expect(fromJson.completedSubTasks, 1);
      expect(fromJson.subTasks.first.title, 'Cari referensi jurnal');
      expect(fromJson.subTasks.first.isDone, true);
    });

    test('Subject isArchived serializes correctly and defaults to false for backward compatibility', () {
      final jsonOldFormat = {
        'id': 'sub_old',
        'name': 'STRUKTUR DATA',
        'colorValue': 0xFF2563EB,
        'tasks': [],
        'notes': [],
      };

      final parsed = Subject.fromJson(jsonOldFormat);
      expect(parsed.isArchived, false);

      final archivedSubject = parsed.copyWith(isArchived: true);
      expect(archivedSubject.isArchived, true);
      final jsonNew = archivedSubject.toJson();
      expect(jsonNew['isArchived'], true);
      final fromJsonNew = Subject.fromJson(jsonNew);
      expect(fromJsonNew.isArchived, true);
    });

    test('DeadlineHelper parses relative and absolute dates accurately', () {
      final todayInfo = DeadlineHelper.parse('Hari ini');
      expect(todayInfo.level, UrgencyLevel.today);
      expect(todayInfo.isUrgent, true);

      final tomorrowInfo = DeadlineHelper.parse('Besok');
      expect(tomorrowInfo.level, UrgencyLevel.tomorrow);
      expect(tomorrowInfo.isUrgent, true);

      final emptyInfo = DeadlineHelper.parse(null);
      expect(emptyInfo.level, UrgencyLevel.none);
      expect(emptyInfo.label, '');

      final textOnlyInfo = DeadlineHelper.parse('Sebelum UAS');
      expect(textOnlyInfo.level, UrgencyLevel.textOnly);
      expect(textOnlyInfo.label, 'Sebelum UAS');
    });

    test('AppProvider getAllTasksWithSubject supports filtering and searching', () async {
      SharedPreferences.setMockInitialValues({
        'is_first_launch_done': true,
        'sample_data_version': 1,
        'saved_subjects_data': jsonEncode([
          Subject(
            id: 'sub_a',
            name: 'ALGORITMA',
            colorValue: 0xFF2563EB,
            tasks: [
              TaskItem(id: 't_a1', subjectId: 'sub_a', title: 'Tugas Sorting', isDone: false, priority: 'high'),
              TaskItem(id: 't_a2', subjectId: 'sub_a', title: 'Tugas Searching', isDone: true),
            ],
          ).toJson(),
          Subject(
            id: 'sub_b',
            name: 'JARINGAN',
            colorValue: 0xFF059669,
            isArchived: true, // Archived subject tasks should be excluded from active global view
            tasks: [
              TaskItem(id: 't_b1', subjectId: 'sub_b', title: 'Laporan Subnetting', isDone: false),
            ],
          ).toJson(),
        ]),
      });

      final provider = AppProvider();
      await provider.waitUntilReady();

      // Filter: all (from active subjects only)
      final allTasks = provider.getAllTasksWithSubject(filter: 'all');
      expect(allTasks.length, 2);

      // Filter: pending
      final pendingTasks = provider.getAllTasksWithSubject(filter: 'pending');
      expect(pendingTasks.length, 1);
      expect(pendingTasks.first.task.title, 'Tugas Sorting');

      // Filter: high priority
      final highTasks = provider.getAllTasksWithSubject(filter: 'high');
      expect(highTasks.length, 1);
      expect(highTasks.first.task.priority, 'high');

      // Filter: completed
      final completedTasks = provider.getAllTasksWithSubject(filter: 'completed');
      expect(completedTasks.length, 1);
      expect(completedTasks.first.task.title, 'Tugas Searching');

      // Query search across title
      final searchResult = provider.getAllTasksWithSubject(query: 'Sorting');
      expect(searchResult.length, 1);
      expect(searchResult.first.task.title, 'Tugas Sorting');
    });

    test('AppProvider toggleArchiveSubject and subtask operations work correctly', () async {
      SharedPreferences.setMockInitialValues({
        'is_first_launch_done': true,
        'sample_data_version': 1,
        'saved_subjects_data': jsonEncode([
          Subject(
            id: 'sub_test_ops',
            name: 'KECERDASAN BUATAN',
            colorValue: 0xFF2563EB,
            tasks: [
              TaskItem(
                id: 't_ai',
                subjectId: 'sub_test_ops',
                title: 'Tugas NLP',
                subTasks: [
                  SubTask(id: 'st_1', title: 'Tokenisasi', isDone: false),
                ],
              ),
            ],
          ).toJson(),
        ]),
      });

      final provider = AppProvider();
      await provider.waitUntilReady();

      expect(provider.activeSubjectCount, 1);
      expect(provider.archivedSubjectCount, 0);

      // Toggle archive
      await provider.toggleArchiveSubject('sub_test_ops');
      expect(provider.activeSubjectCount, 0);
      expect(provider.archivedSubjectCount, 1);

      // Unarchive
      await provider.toggleArchiveSubject('sub_test_ops');
      expect(provider.activeSubjectCount, 1);

      // Add subtask
      await provider.addSubTask('sub_test_ops', 't_ai', 'Stemming & Lemmatization');
      var subject = provider.getSubjectById('sub_test_ops')!;
      var task = subject.tasks.firstWhere((t) => t.id == 't_ai');
      expect(task.subTasks.length, 2);
      expect(task.subTasks[1].title, 'Stemming & Lemmatization');

      // Toggle subtask status
      await provider.toggleSubTask('sub_test_ops', 't_ai', 'st_1');
      subject = provider.getSubjectById('sub_test_ops')!;
      task = subject.tasks.firstWhere((t) => t.id == 't_ai');
      expect(task.subTasks[0].isDone, true);

      // Delete subtask
      await provider.deleteSubTask('sub_test_ops', 't_ai', 'st_1');
      subject = provider.getSubjectById('sub_test_ops')!;
      task = subject.tasks.firstWhere((t) => t.id == 't_ai');
      expect(task.subTasks.length, 1);
      expect(task.subTasks[0].title, 'Stemming & Lemmatization');
    });

    test('DeadlineHelper parseDate parses various formats accurately', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(DeadlineHelper.parseDate('Hari ini'), today);
      expect(DeadlineHelper.parseDate('Besok'), today.add(const Duration(days: 1)));
      expect(DeadlineHelper.parseDate('kemarin'), today.subtract(const Duration(days: 1)));

      final isoDate = DeadlineHelper.parseDate('2026-12-25');
      expect(isoDate, DateTime(2026, 12, 25));

      final textDate = DeadlineHelper.parseDate('25 Dec 2026');
      expect(textDate, DateTime(2026, 12, 25));

      expect(DeadlineHelper.parseDate('Sebelum UAS'), isNull);
      expect(DeadlineHelper.parseDate(null), isNull);
      expect(DeadlineHelper.parseDate(''), isNull);
    });
  });
}
