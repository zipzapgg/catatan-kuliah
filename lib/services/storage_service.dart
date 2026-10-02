import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../models/note_item.dart';

class StorageException implements Exception {
  final String message;
  const StorageException([this.message = 'Data belum tersimpan. Coba lagi.']);
  @override
  String toString() => message;
}

class StorageService {
  static const String _subjectsKey = 'saved_subjects_data';
  static const String _firstTimeKey = 'is_first_launch_done';
  static const String _sampleDataVersionKey = 'sample_data_version';
  static const int _sampleDataVersion = 1;

  /// Memuat daftar seluruh mata kuliah beserta tugas & note dari SharedPreferences
  Future<List<Subject>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();

    final isFirstLaunchDone = prefs.getBool(_firstTimeKey) ?? false;
    final rawJson = prefs.getString(_subjectsKey);
    if (!isFirstLaunchDone && rawJson == null) {
      // Masukkan data awal sesuai contoh di PRD Bab 1
      final initialData = _getInitialSampleData();
      await saveSubjects(initialData);
      await prefs.setBool(_firstTimeKey, true);
      await prefs.setInt(_sampleDataVersionKey, _sampleDataVersion);
      return initialData;
    }

    if (rawJson == null || rawJson.trim().isEmpty) {
      return [];
    }

    try {
      final subjects = importFromJson(rawJson);
      if (subjects == null) throw const FormatException();
      if ((prefs.getInt(_sampleDataVersionKey) ?? 0) < _sampleDataVersion) {
        final mergedSubjects = _mergeMissingSampleSubjects(subjects);
        await saveSubjects(mergedSubjects);
        await prefs.setInt(_sampleDataVersionKey, _sampleDataVersion);
        return mergedSubjects;
      }
      return subjects;
    } on StorageException {
      rethrow;
    } catch (_) {
      throw const FormatException('Data tersimpan tidak dapat dibaca.');
    }
  }

  /// Menyimpan daftar mata kuliah ke SharedPreferences
  Future<bool> saveSubjects(List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = subjects.map((s) => s.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    try {
      if (await prefs.setString(_subjectsKey, encoded)) return true;
    } catch (_) {
      await prefs.reload();
      throw const StorageException();
    }
    await prefs.reload();
    throw const StorageException();
  }

  /// Ekspor seluruh data dalam bentuk teks JSON
  String exportToJson(List<Subject> subjects) {
    final jsonList = subjects.map((s) => s.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Impor data dari teks JSON
  List<Subject>? importFromJson(String jsonString) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final subjects = decoded
          .map((item) => Subject.fromJson(item as Map<String, dynamic>))
          .toList();
      final ids = <String>{};
      final taskIds = <String>{};
      final noteIds = <String>{};
      for (final subject in subjects) {
        if (subject.id.trim().isEmpty ||
            subject.name.trim().isEmpty ||
            !ids.add(subject.id)) {
          return null;
        }
        if (subject.colorValue < 0 || subject.colorValue > 0xFFFFFFFF) {
          return null;
        }
        if (subject.scheduleDay != null &&
            subject.scheduleDay!.isNotEmpty &&
            ![
              'Senin',
              'Selasa',
              'Rabu',
              'Kamis',
              'Jumat',
              'Sabtu',
              'Minggu',
            ].contains(subject.scheduleDay)) {
          return null;
        }
        for (final task in subject.tasks) {
          if (task.id.trim().isEmpty ||
              task.title.trim().isEmpty ||
              task.subjectId != subject.id ||
              !taskIds.add(task.id) ||
              !['normal', 'high', 'low'].contains(task.priority)) {
            return null;
          }
          final subIds = <String>{};
          for (final subTask in task.subTasks) {
            if (subTask.id.trim().isEmpty ||
                subTask.title.trim().isEmpty ||
                !subIds.add(subTask.id)) {
              return null;
            }
          }
        }
        for (final note in subject.notes) {
          if (note.id.trim().isEmpty ||
              note.content.trim().isEmpty ||
              note.subjectId != subject.id ||
              !noteIds.add(note.id)) {
            return null;
          }
        }
      }
      return subjects;
    } catch (_) {
      return null;
    }
  }

  List<Subject> _mergeMissingSampleSubjects(List<Subject> subjects) {
    final existingNames = subjects
        .map((subject) => subject.name.toLowerCase())
        .toSet();
    return [
      ...subjects,
      ..._getInitialSampleData().where(
        (subject) => existingNames.add(subject.name.toLowerCase()),
      ),
    ];
  }

  /// Data sampel awal sesuai PRD
  List<Subject> _getInitialSampleData() {
    final subjectId = 'sample_sub_1';
    return [
      Subject(
        id: subjectId,
        name: 'MANAJEMEN PROJEK',
        colorValue: 0xFF2563EB, // Royal Blue
        scheduleDay: 'Senin',
        scheduleTime: '08:00 - 10:30',
        room: 'R. 304 (Gedung B)',
        lecturer: 'Drs. Supriyanto, M.M.',
        createdAt: DateTime.now(),
        tasks: [
          TaskItem(
            id: 'sample_task_1',
            subjectId: subjectId,
            title: 'buat makalah template kp',
            isDone: false,
            deadline: 'Sebelum UTS',
            order: 0,
          ),
          TaskItem(
            id: 'sample_task_2',
            subjectId: subjectId,
            title: 'ppt',
            isDone: false,
            deadline: 'Sebelum UTS',
            order: 1,
          ),
        ],
        notes: [
          NoteItem(
            id: 'sample_note_1',
            subjectId: subjectId,
            content:
                'makalah nya pasti nge print banyak, ppt harus ngejelasin sesuai ketentuan dan program yang dibuat lancar',
            createdAt: DateTime.now(),
          ),
        ],
      ),
      Subject(
        id: 'sample_sub_2',
        name: 'ARSITEKTUR DAN ORGANISASI KOMPUTER',
        colorValue: 0xFF7C3AED,
        scheduleDay: 'Rabu',
        scheduleTime: '13:00 - 15:30',
        room: 'Lab Hardware (Lt. 2)',
        lecturer: 'Dr. Hendra, S.T., M.Kom.',
        createdAt: DateTime.now(),
        tasks: [
          TaskItem(
            id: 'sample_task_3',
            subjectId: 'sample_sub_2',
            title: 'buat kelompok',
          ),
          TaskItem(
            id: 'sample_task_4',
            subjectId: 'sample_sub_2',
            title: 'buat stress test (dokumentasi dan data)',
            deadline: 'Sebelum UTS',
            order: 1,
          ),
          TaskItem(
            id: 'sample_task_5',
            subjectId: 'sample_sub_2',
            title: 'buat jurnal dari hasil stress test',
            deadline: 'Sebelum UAS',
            order: 2,
          ),
        ],
      ),
      Subject(
        id: 'sample_sub_3',
        name: 'KECAKAPAN ANTAR PERSONAL',
        colorValue: 0xFF059669,
        scheduleDay: 'Kamis',
        scheduleTime: '10:00 - 11:40',
        room: 'Auditorium 2',
        lecturer: 'Siti Rahma, M.Psi.',
        createdAt: DateTime.now(),
        tasks: [
          TaskItem(
            id: 'sample_task_6',
            subjectId: 'sample_sub_3',
            title: 'buat kelompok',
          ),
          TaskItem(
            id: 'sample_task_7',
            subjectId: 'sample_sub_3',
            title: 'buat ppt',
            order: 1,
          ),
        ],
        notes: [
          NoteItem(
            id: 'sample_note_2',
            subjectId: 'sample_sub_3',
            content: 'Harus lancar sesuai kemampuan individu.',
            createdAt: DateTime.now(),
          ),
        ],
      ),
    ];
  }
}
