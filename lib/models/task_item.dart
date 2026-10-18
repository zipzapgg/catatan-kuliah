import 'academic_schedule.dart';
import 'task_attachment.dart';
import '../utils/deadline_helper.dart';

class SubTask {
  final String id;
  final String title;
  final bool isDone;

  SubTask({required this.id, required this.title, this.isDone = false});

  SubTask copyWith({String? id, String? title, bool? isDone}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'isDone': isDone};
  }

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
    );
  }
}

class TaskItem {
  static const _unchanged = Object();
  final String id;
  final String subjectId;
  final String title;
  final String status;
  bool get isDone => status == 'submitted';
  final String? deadline;
  final String priority; // 'high', 'normal', 'low'
  final int order;
  final DateTime createdAt;
  final List<SubTask> subTasks;
  final int? deadlineMinutes;
  final List<int> reminderMinutes;
  final String kind;
  final String description;
  final int repeatDays;
  final String? seriesId;
  final List<TaskAttachment> attachments;
  static const statuses = {
    'todo': 'Belum mulai',
    'doing': 'Dikerjakan',
    'ready': 'Siap dikumpulkan',
    'submitted': 'Terkumpul',
  };
  static const kinds = {
    'task': 'Tugas',
    'exam': 'Ujian',
    'presentation': 'Presentasi',
  };
  DateTime? get dueAt {
    final date = DeadlineHelper.parseDate(deadline);
    final minutes = deadlineMinutes ?? 1439;
    return date == null
        ? null
        : DateTime(
            date.year,
            date.month,
            date.day,
            minutes ~/ 60,
            minutes % 60,
          );
  }

  String get timeLabel => deadlineMinutes == null
      ? ''
      : '${(deadlineMinutes! ~/ 60).toString().padLeft(2, '0')}:${(deadlineMinutes! % 60).toString().padLeft(2, '0')}';
  void validate() {
    if (!statuses.containsKey(status) ||
        !kinds.containsKey(kind) ||
        (deadlineMinutes != null &&
            (deadlineMinutes! < 0 || deadlineMinutes! > 1439)) ||
        reminderMinutes.length > 5 ||
        reminderMinutes.any((m) => m < 0 || m > 10080) ||
        ![0, 1, 7, 14].contains(repeatDays) ||
        (repeatDays != 0 && dueAt == null) ||
        attachments.length > 10 ||
        attachments.map((a) => a.id).toSet().length != attachments.length) {
      throw const FormatException(
        'Periksa deadline, pengingat, status, dan lampiran tugas.',
      );
    }
    for (final a in attachments) {
      a.validate();
    }
  }

  DateTime? nextDeadline(DateTime now) {
    if (repeatDays == 0 || dueAt == null) return null;
    var next = shiftDays(dueAt!, repeatDays);
    while (!next.isAfter(now)) {
      next = shiftDays(next, repeatDays);
    }
    return next;
  }

  TaskItem({
    required this.id,
    required this.subjectId,
    required this.title,
    bool isDone = false,
    String? status,
    this.deadline,
    this.priority = 'normal',
    this.order = 0,
    DateTime? createdAt,
    List<SubTask>? subTasks,
    this.deadlineMinutes,
    this.reminderMinutes = const [1440, 60],
    this.kind = 'task',
    this.description = '',
    this.repeatDays = 0,
    this.seriesId,
    this.attachments = const [],
  }) : status = status ?? (isDone ? 'submitted' : 'todo'),
       createdAt = createdAt ?? DateTime.now(),
       subTasks = subTasks ?? [];

  int get totalSubTasks => subTasks.length;
  int get completedSubTasks => subTasks.where((s) => s.isDone).length;
  bool get hasSubTasks => subTasks.isNotEmpty;

  TaskItem copyWith({
    String? id,
    String? subjectId,
    String? title,
    bool? isDone,
    Object? deadline = _unchanged,
    String? priority,
    int? order,
    DateTime? createdAt,
    List<SubTask>? subTasks,
    String? status,
    Object? deadlineMinutes = _unchanged,
    List<int>? reminderMinutes,
    String? kind,
    String? description,
    int? repeatDays,
    String? seriesId,
    List<TaskAttachment>? attachments,
  }) {
    return TaskItem(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      status:
          status ??
          (isDone == null
              ? this.status
              : isDone
              ? 'submitted'
              : 'todo'),
      deadline: identical(deadline, _unchanged)
          ? this.deadline
          : deadline as String?,
      priority: priority ?? this.priority,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      subTasks: subTasks ?? List.from(this.subTasks),
      deadlineMinutes: identical(deadlineMinutes, _unchanged)
          ? this.deadlineMinutes
          : deadlineMinutes as int?,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      repeatDays: repeatDays ?? this.repeatDays,
      seriesId: seriesId ?? this.seriesId,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'title': title,
      'isDone': isDone,
      'status': status,
      'deadline': deadline,
      'priority': priority,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
      'deadlineMinutes': deadlineMinutes,
      'reminderMinutes': reminderMinutes,
      'kind': kind,
      'description': description,
      'repeatDays': repeatDays,
      'seriesId': seriesId,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
      status: json['status'] as String?,
      deadlineMinutes: json['deadlineMinutes'] as int?,
      reminderMinutes: (json['reminderMinutes'] as List? ?? [959]).cast<int>(),
      kind: json['kind'] as String? ?? 'task',
      description: json['description'] as String? ?? '',
      repeatDays: json['repeatDays'] as int? ?? 0,
      seriesId: json['seriesId'] as String?,
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => TaskAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      deadline: json['deadline'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      order: json['order'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      subTasks:
          (json['subTasks'] as List<dynamic>?)
              ?.map((s) => SubTask.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
