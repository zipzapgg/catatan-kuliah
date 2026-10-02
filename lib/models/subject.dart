import 'task_item.dart';
import 'note_item.dart';

class Subject {
  static const _unchanged = Object();
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  final String? scheduleDay; // Mis: 'Senin', 'Selasa', 'Rabu', dsb.
  final String? scheduleTime; // Mis: '08:00 - 10:30'
  final String? room; // Mis: 'R. 304' / 'Lab Komputer 2'
  final String? lecturer; // Mis: 'Dr. Budi, M.Kom'
  final bool isArchived;
  final List<TaskItem> tasks;
  final List<NoteItem> notes;

  Subject({
    required this.id,
    required this.name,
    required this.colorValue,
    DateTime? createdAt,
    this.scheduleDay,
    this.scheduleTime,
    this.room,
    this.lecturer,
    this.isArchived = false,
    List<TaskItem>? tasks,
    List<NoteItem>? notes,
  }) : createdAt = createdAt ?? DateTime.now(),
       tasks = tasks ?? [],
       notes = notes ?? [];

  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isDone).length;
  int get pendingTasks => totalTasks - completedTasks;

  double get progressPercentage {
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }

  String get progressText => '$completedTasks/$totalTasks tugas selesai';

  bool get hasSchedule =>
      (scheduleDay != null && scheduleDay!.isNotEmpty) ||
      (scheduleTime != null && scheduleTime!.isNotEmpty);

  Subject copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    Object? scheduleDay = _unchanged,
    Object? scheduleTime = _unchanged,
    Object? room = _unchanged,
    Object? lecturer = _unchanged,
    bool? isArchived,
    List<TaskItem>? tasks,
    List<NoteItem>? notes,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      scheduleDay: identical(scheduleDay, _unchanged)
          ? this.scheduleDay
          : scheduleDay as String?,
      scheduleTime: identical(scheduleTime, _unchanged)
          ? this.scheduleTime
          : scheduleTime as String?,
      room: identical(room, _unchanged) ? this.room : room as String?,
      lecturer: identical(lecturer, _unchanged)
          ? this.lecturer
          : lecturer as String?,
      isArchived: isArchived ?? this.isArchived,
      tasks: tasks ?? List.from(this.tasks),
      notes: notes ?? List.from(this.notes),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'scheduleDay': scheduleDay,
      'scheduleTime': scheduleTime,
      'room': room,
      'lecturer': lecturer,
      'isArchived': isArchived,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
    };
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int? ?? 0xFF1E88E5,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      scheduleDay: json['scheduleDay'] as String?,
      scheduleTime: json['scheduleTime'] as String?,
      room: json['room'] as String?,
      lecturer: json['lecturer'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      notes:
          (json['notes'] as List<dynamic>?)
              ?.map((n) => NoteItem.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
