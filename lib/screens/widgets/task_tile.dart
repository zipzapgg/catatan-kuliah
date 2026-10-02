import 'package:flutter/material.dart';
import '../../models/task_item.dart';
import '../../utils/deadline_helper.dart';

class TaskTile extends StatefulWidget {
  final TaskItem task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final bool showDragHandle;
  final int? dragIndex;
  final bool busy;
  final void Function(String subTaskId)? onToggleSubTask;
  final String? subjectName;
  final Color? subjectColor;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.showDragHandle = false,
    this.dragIndex,
    this.busy = false,
    this.onToggleSubTask,
    this.subjectName,
    this.subjectColor,
  }) : assert(!showDragHandle || dragIndex != null);

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _expanded = false;
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting || widget.busy) return;
    setState(() => _deleting = true);
    try {
      await widget.onDelete();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final task = widget.task;
    final disabled = widget.busy || _deleting;
    final deadline = DeadlineHelper.parse(task.deadline);
    final urgent =
        !task.isDone &&
        (deadline.level == UrgencyLevel.overdue ||
            deadline.level == UrgencyLevel.today);
    final metadata = <String>[
      if (!task.isDone && task.priority == 'high') 'Prioritas tinggi',
      if (task.deadline != null)
        '${DeadlineHelper.display(task.deadline)}${!task.isDone && deadline.label.isNotEmpty && deadline.label != task.deadline ? ' · ${deadline.label}' : ''}',
    ];
    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      direction: disabled ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        await _delete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: task.isDone
                        ? 'Tandai ${task.title} belum selesai'
                        : 'Selesaikan ${task.title}',
                    child: Checkbox(
                      value: task.isDone,
                      onChanged: disabled ? null : widget.onToggle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3, right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.subjectName != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          widget.subjectColor ?? colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.subjectName!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            task.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: task.isDone
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (metadata.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              metadata.join('\n'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    urgent ||
                                        (!task.isDone &&
                                            task.priority == 'high')
                                    ? colors.error
                                    : colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  if (task.hasSubTasks)
                    TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                      label: Text(
                        '${task.completedSubTasks}/${task.totalSubTasks} langkah',
                      ),
                    ),
                  if (task.isDone && !task.hasSubTasks)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text('Selesai', style: theme.textTheme.bodySmall),
                    ),
                  IconButton(
                    tooltip: 'Edit tugas',
                    onPressed: disabled ? null : widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 21),
                  ),
                  IconButton(
                    tooltip: 'Hapus tugas',
                    onPressed: disabled ? null : _delete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 21,
                      color: colors.error,
                    ),
                  ),
                  if (widget.showDragHandle)
                    Semantics(
                      label: 'Seret untuk mengurutkan tugas',
                      child: ReorderableDragStartListener(
                        index: widget.dragIndex!,
                        enabled: !disabled,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.drag_handle,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_expanded && task.hasSubTasks) ...[
                const Divider(height: 16),
                ...task.subTasks.map(
                  (step) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: 'Langkah: ${step.title}',
                        child: Checkbox(
                          value: step.isDone,
                          onChanged: disabled || widget.onToggleSubTask == null
                              ? null
                              : (_) => widget.onToggleSubTask!(step.id),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            step.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: step.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: step.isDone
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
