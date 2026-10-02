import 'package:flutter/material.dart';
import '../../models/subject.dart';

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onArchive;
  final bool busy;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onArchive,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final schedule = [
      if (subject.scheduleDay?.isNotEmpty == true) subject.scheduleDay!,
      if (subject.scheduleTime?.isNotEmpty == true) subject.scheduleTime!,
      if (subject.room?.isNotEmpty == true) subject.room!,
    ].join(' · ');
    final pending = subject.tasks.where((task) => !task.isDone).toList();
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(subject.colorValue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          subject.isArchived
                              ? 'Diarsipkan'
                              : '${pending.length} tugas tersisa · ${subject.notes.length} catatan',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip: 'Opsi ${subject.name}',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'archive') onArchive?.call();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit mata kuliah'),
                      ),
                      if (onArchive != null)
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            subject.isArchived
                                ? 'Keluarkan dari arsip'
                                : 'Arsipkan mata kuliah',
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Hapus mata kuliah',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (schedule.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(schedule, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ],
              if (subject.totalTasks > 0) ...[
                const SizedBox(height: 20),
                Text(
                  '${subject.completedTasks} dari ${subject.totalTasks} tugas selesai',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: subject.progressPercentage,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ],
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pending.first.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18, color: colors.primary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
