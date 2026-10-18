import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../models/note_item.dart';
import '../models/academic_schedule.dart';
import '../models/unpam_calendar.dart';
import '../models/tuition_payment.dart';
import '../models/academic_event.dart';
import '../models/document_draft.dart';
import '../models/task_attachment.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../utils/deadline_helper.dart';

enum SortOption { byPendingTasks, byRecent, byName }

class AppProvider extends ChangeNotifier {
  static const _unchanged = Object();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  List<Subject> _subjects = [];
  List<TuitionPayment> _payments = [];
  List<AcademicEvent> _events = [];
  List<AcademicEvent> get events => List.unmodifiable(_events);
  List<AcademicEvent> get visibleEvents => _events
      .where((e) => _semester == null || e.semester == _semester)
      .toList();
  List<TuitionPayment> get payments => List.unmodifiable(_payments);
  List<TuitionPayment> get visiblePayments {
    final result = _payments
        .where((p) => _semester == null || p.semester == _semester)
        .toList();
    result.sort(
      (a, b) => a.isPaid != b.isPaid
          ? (a.isPaid ? 1 : -1)
          : (a.dueAt ?? DateTime(2101)).compareTo(b.dueAt ?? DateTime(2101)),
    );
    return result;
  }

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDarkMode = false;
  bool _showArchived = false;
  bool _disposed = false;
  String _searchQuery = '';
  String? _semester;
  String? get semester => _semester;
  List<String> get semesters => {
    ..._subjects.map((s) => s.semester),
    ..._payments.map((p) => p.semester),
    ..._events.map((e) => e.semester),
  }.toList()..sort();
  List<Subject> get visibleSubjects => _subjects
      .where(
        (s) => !s.isArchived && (_semester == null || s.semester == _semester),
      )
      .toList();
  void setSemester(String? value) {
    _semester = value;
    _notify();
  }

  List<ExamBreak> breaksForSemester(String semester) {
    final breaks = List<ExamBreak>.of(
      _subjects.where((s) => s.semester == semester).firstOrNull?.examBreaks ??
          (semester == UnpamCalendar.semester ? UnpamCalendar.examBreaks : []),
    );
    for (final e in _events.where(
      (e) => e.semester == semester && e.kind != 'event',
    )) {
      breaks.removeWhere((b) => b.name == e.kind);
      breaks.add(ExamBreak(name: e.kind, start: e.start, end: e.end));
    }
    return breaks;
  }

  SortOption _sortOption = SortOption.byPendingTasks;
  String? _loadError;
  String? _reminderError;
  int _sequence = 0;
  Future<void> _pendingWrite = Future.value();
  late final Future<void> _initFuture;

  AppProvider() {
    _initFuture = _init();
  }

  List<Subject> get subjects => List.unmodifiable(_subjects);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDarkMode => _isDarkMode;
  bool get showArchived => _showArchived;
  String get searchQuery => _searchQuery;
  SortOption get sortOption => _sortOption;
  bool get hasLoadError => _loadError != null;
  String? get loadError => _loadError;
  String? get reminderError => _reminderError;
  Future<void> get initFuture => _initFuture;
  int get activeSubjectCount => _subjects.where((s) => !s.isArchived).length;
  int get archivedSubjectCount => _subjects.where((s) => s.isArchived).length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> waitUntilReady() => _initFuture;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      await loadData();
    } catch (_) {
      _loadError = 'Penyimpanan lokal belum dapat dibuka. Coba muat ulang.';
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    _notify();
    try {
      final loaded = await _storageService.loadSubjects();
      final loadedPayments = await _storageService.loadPayments();
      final loadedEvents = await _storageService.loadEvents();
      final normalized = loaded
          .map(
            (subject) => subject.copyWith(
              tasks: [
                for (int i = 0; i < subject.tasks.length; i++)
                  subject.tasks[i].copyWith(
                    order: i,
                    deadline: DeadlineHelper.normalize(
                      subject.tasks[i].deadline,
                      reference: subject.tasks[i].createdAt,
                    ),
                  ),
              ],
            ),
          )
          .toList();
      if (_storageService.exportToJson(loaded) !=
          _storageService.exportToJson(normalized)) {
        await _storageService.saveSubjects(
          normalized,
          payments: loadedPayments,
          events: loadedEvents,
        );
      }
      _subjects = normalized;
      _payments = loadedPayments;
      _events = loadedEvents;
      _loadError = null;
      await _syncReminders();
    } on FormatException {
      _loadError =
          'Data lokal tidak dapat dibaca. Pulihkan dari cadangan agar data tidak tertimpa.';
    } catch (_) {
      _loadError =
          'Data lokal belum dapat dimuat. Coba lagi atau pulihkan cadangan.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _commit(
    List<Subject> Function(List<Subject>) change, {
    bool reminders = false,
    bool recovery = false,
    List<TuitionPayment> Function(List<TuitionPayment>)? changePayments,
    List<AcademicEvent> Function(List<AcademicEvent>)? changeEvents,
  }) {
    final operation = _pendingWrite.then((_) async {
      await waitUntilReady();
      if (hasLoadError && !recovery) {
        throw const StorageException(
          'Pulihkan data lokal sebelum membuat perubahan.',
        );
      }
      _isSaving = true;
      _notify();
      try {
        final next = change(List.of(_subjects));
        final nextPayments =
            changePayments?.call(List.of(_payments)) ?? List.of(_payments);
        final nextEvents =
            changeEvents?.call(List.of(_events)) ?? List.of(_events);
        if (_storageService.importFromJson(
              _storageService.exportToJson(
                next,
                payments: nextPayments,
                events: nextEvents,
              ),
            ) ==
            null) {
          throw const FormatException(
            'Data tidak valid. Periksa isian sebelum menyimpan.',
          );
        }
        await _storageService.saveSubjects(
          next,
          payments: nextPayments,
          events: nextEvents,
        );
        _subjects = next;
        _payments = nextPayments;
        _events = nextEvents;
        if (_semester != null && !semesters.contains(_semester)) {
          _semester = null;
        }
        _loadError = null;
        if (reminders) await _syncReminders();
      } finally {
        _isSaving = false;
        _notify();
      }
    });
    // Failed writes must not poison the queue or publish unsaved state.
    _pendingWrite = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _changeSubject(
    String id,
    Subject Function(Subject) edit, {
    bool reminders = false,
  }) => _commit((subjects) {
    final index = subjects.indexWhere((s) => s.id == id);
    if (index < 0) {
      throw const StorageException('Mata kuliah ini sudah tidak tersedia.');
    }
    final updated = edit(subjects[index]);
    subjects[index] = updated.copyWith(
      tasks: [
        for (int i = 0; i < updated.tasks.length; i++)
          updated.tasks[i].copyWith(order: i),
      ],
    );
    return subjects;
  }, reminders: reminders);

  Future<void> _changeTask(
    String subjectId,
    String taskId,
    TaskItem Function(TaskItem) edit, {
    bool reminders = false,
  }) => _changeSubject(subjectId, (subject) {
    final tasks = List.of(subject.tasks);
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) {
      throw const StorageException('Tugas ini sudah tidak tersedia.');
    }
    tasks[index] = edit(tasks[index]);
    return subject.copyWith(tasks: tasks);
  }, reminders: reminders);

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
  String? _optional(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _required(String value, String label) {
    if (value.trim().isEmpty) throw FormatException('$label wajib diisi.');
    return value.trim();
  }

  Future<void> toggleDarkMode() async {
    final next = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool('is_dark_mode', next)) {
      throw const StorageException();
    }
    _isDarkMode = next;
    _notify();
  }

  void setShowArchived(bool value) {
    _showArchived = value;
    _notify();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _notify();
  }

  void setSortOption(SortOption value) {
    _sortOption = value;
    _notify();
  }

  List<Subject> get filteredSubjects {
    final q = _searchQuery.trim().toLowerCase();
    final result = _subjects
        .where(
          (s) =>
              s.isArchived == _showArchived &&
              (_semester == null || s.semester == _semester) &&
              (q.isEmpty ||
                  s.name.toLowerCase().contains(q) ||
                  s.tasks.any((t) => t.title.toLowerCase().contains(q)) ||
                  s.notes.any((n) => n.content.toLowerCase().contains(q))),
        )
        .toList();
    result.sort(
      (a, b) => switch (_sortOption) {
        SortOption.byPendingTasks =>
          b.pendingTasks != a.pendingTasks
              ? b.pendingTasks.compareTo(a.pendingTasks)
              : b.createdAt.compareTo(a.createdAt),
        SortOption.byRecent => b.createdAt.compareTo(a.createdAt),
        SortOption.byName => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      },
    );
    return result;
  }

  List<({TaskItem task, Subject subject})> get allPendingTasksWithSubject =>
      getAllTasksWithSubject(filter: 'pending');

  List<({TaskItem task, Subject subject})> getAllTasksWithSubject({
    String filter = 'all',
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    final list = <({TaskItem task, Subject subject})>[];
    for (final subject in visibleSubjects) {
      for (final task in subject.tasks) {
        if (filter == 'pending' && task.isDone ||
            filter == 'completed' && !task.isDone ||
            filter == 'high' && (task.priority != 'high' || task.isDone)) {
          continue;
        }
        if (q.isNotEmpty &&
            !task.title.toLowerCase().contains(q) &&
            !subject.name.toLowerCase().contains(q) &&
            !task.subTasks.any((s) => s.title.toLowerCase().contains(q))) {
          continue;
        }
        list.add((task: task, subject: subject));
      }
    }
    list.sort((a, b) {
      if (a.task.isDone != b.task.isDone) return a.task.isDone ? 1 : -1;
      const priorities = {'high': 0, 'normal': 1, 'low': 2};
      final priority = priorities[a.task.priority]!.compareTo(
        priorities[b.task.priority]!,
      );
      if (priority != 0) return priority;
      final aDate = DeadlineHelper.parseDate(a.task.deadline);
      final bDate = DeadlineHelper.parseDate(b.task.deadline);
      if (aDate != null && bDate != null) {
        final date = aDate.compareTo(bDate);
        if (date != 0) return date;
      } else if (aDate != null || bDate != null) {
        return aDate != null ? -1 : 1;
      }
      return a.task.createdAt.compareTo(b.task.createdAt);
    });
    return list;
  }

  Map<String, List<Subject>> get subjectsByDay {
    final map = <String, List<Subject>>{};
    for (final day in [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
      'Belum Terjadwal',
    ]) {
      final list = _subjects
          .where(
            (s) =>
                !s.isArchived &&
                (_semester == null || s.semester == _semester) &&
                (s.scheduleDay == day ||
                    day == 'Belum Terjadwal' &&
                        (s.scheduleDay == null || s.scheduleDay!.isEmpty)),
          )
          .toList();
      int startMinutes(Subject subject) {
        final match = RegExp(
          r'^(\d{1,2})[:.](\d{2})',
        ).firstMatch(subject.scheduleTime ?? '');
        return match == null
            ? 24 * 60
            : int.parse(match[1]!) * 60 + int.parse(match[2]!);
      }

      list.sort((a, b) => startMinutes(a).compareTo(startMinutes(b)));
      if (list.isNotEmpty) map[day] = list;
    }
    return map;
  }

  Future<void> addSubject(
    String name,
    int colorValue, {
    String? scheduleDay,
    String? scheduleTime,
    String? room,
    String? lecturer,
    String semester = '',
    MentariSchedule? mentari,
  }) => _commit(
    (subjects) => subjects
      ..insert(
        0,
        Subject(
          id: _newId('sub'),
          name: _required(name, 'Nama mata kuliah'),
          colorValue: colorValue,
          scheduleDay: _optional(scheduleDay),
          scheduleTime: _optional(scheduleTime),
          room: _optional(room),
          lecturer: _optional(lecturer),
          semester: semester.trim(),
          mentari: mentari,
          examBreaks: breaksForSemester(semester.trim()),
        ),
      ),
    reminders: true,
  );

  Future<void> updateSubject(
    String id,
    String name,
    int colorValue, {
    Object? newScheduleDay = _unchanged,
    Object? newScheduleTime = _unchanged,
    Object? newRoom = _unchanged,
    Object? newLecturer = _unchanged,
    String? newSemester,
    Object? newMentari = _unchanged,
  }) => _changeSubject(
    id,
    (s) => s.copyWith(
      name: _required(name, 'Nama mata kuliah'),
      colorValue: colorValue,
      scheduleDay: identical(newScheduleDay, _unchanged)
          ? s.scheduleDay
          : _optional(newScheduleDay),
      scheduleTime: identical(newScheduleTime, _unchanged)
          ? s.scheduleTime
          : _optional(newScheduleTime),
      room: identical(newRoom, _unchanged) ? s.room : _optional(newRoom),
      lecturer: identical(newLecturer, _unchanged)
          ? s.lecturer
          : _optional(newLecturer),
      semester: newSemester?.trim(),
      mentari: identical(newMentari, _unchanged)
          ? s.mentari
          : newMentari as MentariSchedule?,
      examBreaks: newSemester != null && newSemester.trim() != s.semester
          ? breaksForSemester(newSemester.trim())
          : s.examBreaks,
    ),
    reminders: true,
  );

  Future<void> toggleArchiveSubject(String id) => _changeSubject(
    id,
    (s) => s.copyWith(isArchived: !s.isArchived),
    reminders: true,
  );
  Future<void> deleteSubject(String id) => _commit(
    (subjects) => subjects..removeWhere((s) => s.id == id),
    reminders: true,
  );
  Future<void> restoreSubject(Subject subject, int index) =>
      _commit((subjects) {
        if (subjects.any((s) => s.id == subject.id)) return subjects;
        return subjects..insert(index.clamp(0, subjects.length), subject);
      }, reminders: true);

  Future<void> addTask(
    String subjectId,
    String title, {
    String? deadline,
    String priority = 'normal',
    List<SubTask>? subTasks,
    Map<String, dynamic>? details,
  }) => _changeSubject(subjectId, (s) {
    if (!['high', 'normal', 'low'].contains(priority)) {
      throw const FormatException('Prioritas tugas tidak valid.');
    }
    return _finishTask(
      s,
      TaskItem(
        id: _newId('task'),
        subjectId: subjectId,
        title: _required(title, 'Judul tugas'),
        deadline: DeadlineHelper.normalize(deadline),
        priority: priority,
        subTasks: subTasks,
        deadlineMinutes: details?['deadlineMinutes'] as int?,
        reminderMinutes:
            details?['reminderMinutes'] as List<int>? ?? const [1440, 60],
        status: details?['status'] as String?,
        kind: details?['kind'] as String? ?? 'task',
        description: details?['description'] as String? ?? '',
        repeatDays: details?['repeatDays'] as int? ?? 0,
        attachments: details?['attachments'] as List<TaskAttachment>? ?? [],
      ),
    );
  }, reminders: true);

  Future<void> toggleTaskStatus(String subjectId, String taskId) =>
      setTaskStatus(subjectId, taskId, null);

  Subject _finishTask(Subject subject, TaskItem updated) {
    final previous = subject.tasks.where((t) => t.id == updated.id).firstOrNull;
    final tasks = [
      for (final t in subject.tasks) t.id == updated.id ? updated : t,
      if (previous == null) updated,
    ];
    final next = updated.nextDeadline(DateTime.now());
    if (previous?.isDone != true && updated.isDone && next != null) {
      final series = updated.seriesId ?? updated.id;
      if (!tasks.any(
        (t) => (t.seriesId ?? t.id) == series && t.deadline == dateKey(next),
      )) {
        tasks.add(
          updated.copyWith(
            id: _newId('task'),
            status: 'todo',
            deadline: dateKey(next),
            seriesId: series,
            createdAt: DateTime.now(),
            subTasks: [
              for (final step in updated.subTasks) step.copyWith(isDone: false),
            ],
          ),
        );
      }
    }
    return subject.copyWith(tasks: tasks);
  }

  Future<void> setTaskStatus(String subjectId, String taskId, String? status) =>
      _changeSubject(subjectId, (s) {
        final task = s.tasks.where((t) => t.id == taskId).firstOrNull;
        if (task == null) {
          throw const StorageException('Tugas sudah tidak tersedia.');
        }
        return _finishTask(
          s,
          task.copyWith(status: status ?? (task.isDone ? 'todo' : 'submitted')),
        );
      }, reminders: true);

  Future<void> setExamBreaks(String semester, List<ExamBreak> breaks) =>
      _commit(
        (subjects) => [
          for (final s in subjects)
            s.semester == semester ? s.copyWith(examBreaks: breaks) : s,
        ],
        reminders: true,
        changeEvents: (events) => [
          ...events.where((e) => e.semester != semester || e.kind == 'event'),
          for (final b in breaks)
            AcademicEvent(
              id: 'exam_${importName(semester)}_${b.name}',
              title: 'Pekan ${b.name}',
              semester: semester,
              kind: b.name,
              start: b.start,
              end: b.end,
            ),
        ],
      );

  Future<void> applyUnpamCalendar() => _commit(
    (subjects) => [
      for (final s in subjects)
        s.semester == UnpamCalendar.semester ||
                (!s.isArchived && s.semester.isEmpty)
            ? s.copyWith(
                semester: UnpamCalendar.semester,
                examBreaks: UnpamCalendar.examBreaks,
              )
            : s,
    ],
    reminders: true,
    changePayments: _withUnpamPayments,
  );

  List<TuitionPayment> _withUnpamPayments(List<TuitionPayment> current) => [
    ...current,
    for (final p in UnpamCalendar.payments)
      if (!current.any((existing) => existing.id == p.id)) p,
  ];

  Future<void> addUnpamPayments() => _commit(
    (subjects) => subjects,
    changePayments: _withUnpamPayments,
    reminders: true,
  );

  Future<void> savePayment(TuitionPayment payment) => _commit(
    (subjects) => subjects,
    changePayments: (current) => [
      for (final p in current) p.id == payment.id ? payment : p,
      if (!current.any((p) => p.id == payment.id)) payment,
    ],
    reminders: true,
  );

  Future<void> setPaymentPaid(String id, bool paid) => _commit(
    (subjects) => subjects,
    changePayments: (current) {
      if (!current.any((p) => p.id == id)) {
        throw const StorageException('Bayaran sudah tidak tersedia.');
      }
      return [
        for (final p in current) p.id == id ? p.copyWith(isPaid: paid) : p,
      ];
    },
    reminders: true,
  );

  Future<void> deletePayment(String id) => _commit(
    (subjects) => subjects,
    changePayments: (current) => current.where((p) => p.id != id).toList(),
    reminders: true,
  );

  /// One durable transaction; existing tasks, notes and Mentari stay attached.
  Future<void> applyDocument({
    required List<Subject> subjects,
    required List<TuitionPayment> payments,
    required List<AcademicEvent> events,
  }) => _commit(
    (current) {
      for (final incoming in subjects) {
        final index = current.indexWhere((s) => s.id == incoming.id);
        if (index < 0) {
          current.add(
            incoming.copyWith(examBreaks: breaksForSemester(incoming.semester)),
          );
        } else {
          final old = current[index];
          current[index] = old.copyWith(
            name: incoming.name,
            semester: incoming.semester,
            scheduleDay: incoming.scheduleDay,
            scheduleTime: incoming.scheduleTime,
            lecturer: incoming.lecturer,
            room: incoming.room,
            examBreaks: old.semester == incoming.semester
                ? old.examBreaks
                : breaksForSemester(incoming.semester),
          );
        }
      }
      for (final event in events.where((e) => e.kind != 'event')) {
        for (var i = 0; i < current.length; i++) {
          final s = current[i];
          if (s.semester != event.semester) continue;
          current[i] = s.copyWith(
            examBreaks: [
              ...s.examBreaks.where((b) => b.name != event.kind),
              ExamBreak(name: event.kind, start: event.start, end: event.end),
            ],
          );
        }
      }
      return current;
    },
    changePayments: (current) {
      for (final p in payments) {
        final index = current.indexWhere((old) => old.id == p.id);
        if (index < 0) {
          current.add(p);
        } else {
          current[index] = p;
        }
      }
      return current;
    },
    changeEvents: (current) {
      for (final e in events) {
        current.removeWhere(
          (old) =>
              old.id == e.id ||
              (e.kind != 'event' &&
                  old.semester == e.semester &&
                  old.kind == e.kind),
        );
        current.add(e);
      }
      return current;
    },
    reminders: true,
  );

  Future<void> setMentariDone(String subjectId, String key, bool done) =>
      _changeSubject(subjectId, (s) {
        final schedule = s.mentari;
        if (schedule == null ||
            !schedule
                .occurrences(
                  from: schedule.firstStart,
                  to: shiftDays(schedule.until, 1),
                  breaks: s.examBreaks,
                )
                .any((o) => o.key == key)) {
          throw const FormatException(
            'Pertemuan Mentari sudah berubah atau sedang libur ujian.',
          );
        }
        return s.copyWith(mentari: schedule.withCompletion(key, done));
      }, reminders: true);

  Future<void> updateTask(
    String subjectId,
    String taskId,
    String title, {
    Object? newDeadline = _unchanged,
    String? newPriority,
    List<SubTask>? newSubTasks,
    Map<String, dynamic>? details,
  }) => _changeSubject(subjectId, (s) {
    final t = s.tasks.where((t) => t.id == taskId).firstOrNull;
    if (t == null) throw const StorageException('Tugas sudah tidak tersedia.');
    final priority = newPriority ?? t.priority;
    if (!['high', 'normal', 'low'].contains(priority)) {
      throw const FormatException('Prioritas tugas tidak valid.');
    }
    final updated = t.copyWith(
      title: _required(title, 'Judul tugas'),
      priority: priority,
      deadline: identical(newDeadline, _unchanged)
          ? t.deadline
          : DeadlineHelper.normalize(newDeadline as String?),
      subTasks: newSubTasks,
      deadlineMinutes: details == null
          ? t.deadlineMinutes
          : details['deadlineMinutes'],
      reminderMinutes: details?['reminderMinutes'] as List<int>?,
      status: details?['status'] as String?,
      kind: details?['kind'] as String?,
      description: details?['description'] as String?,
      repeatDays: details?['repeatDays'] as int?,
      attachments: details?['attachments'] as List<TaskAttachment>?,
    );
    return _finishTask(s, updated);
  }, reminders: true);

  Future<void> deleteTask(String subjectId, String taskId) => _changeSubject(
    subjectId,
    (s) => s.copyWith(tasks: s.tasks.where((t) => t.id != taskId).toList()),
    reminders: true,
  );
  Future<void> restoreTask(String subjectId, TaskItem task, int index) =>
      _changeSubject(subjectId, (s) {
        if (s.tasks.any((t) => t.id == task.id)) return s;
        final tasks = List.of(s.tasks)
          ..insert(index.clamp(0, s.tasks.length), task);
        return s.copyWith(tasks: tasks);
      }, reminders: true);
  Future<void> reorderTasks(String subjectId, int oldIndex, int newIndex) =>
      _changeSubject(subjectId, (s) {
        final tasks = List.of(s.tasks);
        if (oldIndex < 0 ||
            oldIndex >= tasks.length ||
            newIndex < 0 ||
            newIndex > tasks.length) {
          throw const FormatException('Urutan tugas tidak valid.');
        }
        if (newIndex > oldIndex) newIndex--;
        final task = tasks.removeAt(oldIndex);
        tasks.insert(newIndex, task);
        return s.copyWith(tasks: tasks);
      });

  Future<void> addSubTask(String subjectId, String taskId, String title) =>
      _changeTask(
        subjectId,
        taskId,
        (t) => t.copyWith(
          subTasks: [
            ...t.subTasks,
            SubTask(id: _newId('step'), title: _required(title, 'Langkah')),
          ],
        ),
      );
  Future<void> toggleSubTask(String subjectId, String taskId, String id) =>
      _changeTask(
        subjectId,
        taskId,
        (t) => t.copyWith(
          subTasks: [
            for (final s in t.subTasks)
              s.id == id ? s.copyWith(isDone: !s.isDone) : s,
          ],
        ),
      );
  Future<void> deleteSubTask(String subjectId, String taskId, String id) =>
      _changeTask(
        subjectId,
        taskId,
        (t) =>
            t.copyWith(subTasks: t.subTasks.where((s) => s.id != id).toList()),
      );

  Future<void> addNote(String subjectId, String content) => _changeSubject(
    subjectId,
    (s) => s.copyWith(
      notes: [
        NoteItem(
          id: _newId('note'),
          subjectId: subjectId,
          content: _required(content, 'Catatan'),
        ),
        ...s.notes,
      ],
    ),
  );
  Future<void> updateNote(String subjectId, String noteId, String content) =>
      _changeSubject(
        subjectId,
        (s) => s.copyWith(
          notes: [
            for (final note in s.notes)
              note.id == noteId
                  ? note.copyWith(
                      content: _required(content, 'Catatan'),
                      updatedAt: DateTime.now(),
                    )
                  : note,
          ],
        ),
      );
  Future<void> deleteNote(String subjectId, String noteId) => _changeSubject(
    subjectId,
    (s) => s.copyWith(notes: s.notes.where((n) => n.id != noteId).toList()),
  );
  Future<void> restoreNote(String subjectId, NoteItem note, int index) =>
      _changeSubject(subjectId, (s) {
        if (s.notes.any((n) => n.id == note.id)) return s;
        return s.copyWith(
          notes: List.of(s.notes)..insert(index.clamp(0, s.notes.length), note),
        );
      });

  Subject? getSubjectById(String id) {
    for (final subject in _subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  String formatSubjectForSharing(Subject subject) {
    final buffer = StringBuffer()..writeln('📚 *${subject.name}*');
    if (subject.hasSchedule) {
      buffer.writeln(
        '🗓️ Jadwal: ${[subject.scheduleDay, subject.scheduleTime, if (subject.room != null) 'Ruang: ${subject.room}'].whereType<String>().join(', ')}',
      );
    }
    if (subject.lecturer != null) {
      buffer.writeln('👨‍🏫 Dosen: ${subject.lecturer}');
    }
    buffer
      ..writeln('📊 Progres: ${subject.progressText}')
      ..writeln();
    for (final task in subject.tasks) {
      final check = task.isDone ? '✅ [SELESAI]' : '⬜ [BELUM]';
      final deadline = task.deadline == null
          ? ''
          : ' (Deadline: ${task.deadline})';
      final priority = task.priority == 'high' ? ' 🔴 [PENTING]' : '';
      buffer.writeln('$check ${task.title}$deadline$priority');
    }
    if (subject.notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Catatan:');
      for (final note in subject.notes) {
        buffer.writeln('• ${note.content}');
      }
    }
    buffer
      ..writeln()
      ..writeln('_Dicatat via Catatan Tugas Kuliah_');
    return buffer.toString();
  }

  String exportData() => _storageService.exportToJson(
    _subjects,
    payments: _payments,
    events: _events,
  );
  Future<bool> importData(String jsonString) async {
    final imported = _storageService.importFromJson(jsonString);
    if (imported == null) return false;
    final normalized = imported
        .map(
          (s) => s.copyWith(
            tasks: [
              for (int i = 0; i < s.tasks.length; i++)
                s.tasks[i].copyWith(
                  order: i,
                  deadline: DeadlineHelper.normalize(
                    s.tasks[i].deadline,
                    reference: s.tasks[i].createdAt,
                  ),
                ),
            ],
          ),
        )
        .toList();
    final importedPayments = _storageService.importPaymentsFromJson(jsonString);
    await _commit(
      (_) => normalized,
      reminders: true,
      recovery: true,
      changePayments: (_) => importedPayments,
      changeEvents: (_) => _storageService.importEventsFromJson(jsonString),
    );
    return true;
  }

  Future<void> enableReminders() async {
    if (!await _notificationService.requestPermission()) {
      throw const StorageException(
        'Izin notifikasi belum aktif. Izinkan pengingat melalui pengaturan HP.',
      );
    }
    await rescheduleAllReminders();
    _reminderError = null;
    _notify();
  }

  Future<void> testSendNotification() async {
    if (!await _notificationService.requestPermission()) {
      throw const StorageException('Izin notifikasi belum aktif.');
    }
    await _notificationService.showInstantNotification(
      id: 9999,
      title: 'Pengingat tugas aktif',
      body: 'Pengingat tugas dan Mentari mengikuti waktu yang kamu pilih.',
    );
  }

  Future<void> _syncReminders() async {
    try {
      await rescheduleAllReminders();
      _reminderError = null;
    } catch (error) {
      _reminderError = error is StateError
          ? 'Data tersimpan. ${error.message}'
          : 'Data tersimpan, tetapi pengingat belum tersinkron. Coba aktifkan pengingat lagi.';
    }
  }

  Future<void> rescheduleAllReminders() async {
    await _notificationService.syncSubjects(_subjects, payments: _payments);
  }
}
