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
  final bool isDone;
  final String? deadline;
  final String priority; // 'high', 'normal', 'low'
  final int order;
  final DateTime createdAt;
  final List<SubTask> subTasks;

  TaskItem({
    required this.id,
    required this.subjectId,
    required this.title,
    this.isDone = false,
    this.deadline,
    this.priority = 'normal',
    this.order = 0,
    DateTime? createdAt,
    List<SubTask>? subTasks,
  }) : createdAt = createdAt ?? DateTime.now(),
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
  }) {
    return TaskItem(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      deadline: identical(deadline, _unchanged)
          ? this.deadline
          : deadline as String?,
      priority: priority ?? this.priority,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      subTasks: subTasks ?? List.from(this.subTasks),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'title': title,
      'isDone': isDone,
      'deadline': deadline,
      'priority': priority,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
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
