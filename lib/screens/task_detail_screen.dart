import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../models/task_item.dart';
import '../utils/app_actions.dart';
import '../services/attachment_service.dart';
import 'widgets/add_task_dialog.dart';
import 'widgets/schedule_fields.dart';

class TaskDetailScreen extends StatelessWidget {
  final AppProvider provider;
  final String subjectId, taskId;
  const TaskDetailScreen({
    super.key,
    required this.provider,
    required this.subjectId,
    required this.taskId,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: provider,
    builder: (context, _) {
      final subject = provider.getSubjectById(subjectId);
      final task = subject?.tasks.where((t) => t.id == taskId).firstOrNull;
      if (subject == null || task == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Detail tugas')),
          body: const Center(child: Text('Tugas sudah dihapus.')),
        );
      }
      final theme = Theme.of(context);
      final statusIndex = TaskItem.statuses.keys.toList().indexOf(task.status);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail tugas'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Edit tugas',
              onPressed: provider.isSaving
                  ? null
                  : () => AddTaskDialog.show(
                      context,
                      initialTask: task,
                      onSave: (data) => provider.updateTask(
                        subjectId,
                        taskId,
                        data['title'],
                        newDeadline: data['deadline'],
                        newPriority: data['priority'],
                        newSubTasks: data['subTasks'],
                        details: data,
                      ),
                    ),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(
                        subject.colorValue,
                      ).withValues(alpha: .12),
                      child: Icon(
                        Icons.school_outlined,
                        color: Color(subject.colorValue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subject.name,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(task.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '${TaskItem.kinds[task.kind]} · ${TaskItem.statuses[task.status]}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'Status ${TaskItem.statuses[task.status]}',
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        Icon(
                          i <= statusIndex
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: i <= statusIndex
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                        if (i < 3)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: i < statusIndex
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(task.status),
                  initialValue: task.status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ubah status'),
                  items: [
                    for (final e in TaskItem.statuses.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: provider.isSaving
                      ? null
                      : (v) => AppActions.run(
                          context,
                          () => provider.setTaskStatus(subjectId, taskId, v),
                        ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi tugas',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          task.dueAt == null
                              ? 'Deadline: ${task.deadline ?? 'Belum ditentukan'}'
                              : 'Deadline: ${dateTimeLabel(task.dueAt!)}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prioritas: ${task.priority == 'high'
                              ? 'Penting'
                              : task.priority == 'low'
                              ? 'Rendah'
                              : 'Normal'}',
                        ),
                        if (task.repeatDays != 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Berulang setiap ${task.repeatDays} hari',
                            ),
                          ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SelectableText(task.description),
                        ],
                      ],
                    ),
                  ),
                ),
                if (task.hasSubTasks) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Langkah pengerjaan',
                    style: theme.textTheme.titleMedium,
                  ),
                  for (final step in task.subTasks)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: step.isDone,
                      title: Text(step.title),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: provider.isSaving
                          ? null
                          : (_) => AppActions.run(
                              context,
                              () => provider.toggleSubTask(
                                subjectId,
                                taskId,
                                step.id,
                              ),
                            ),
                    ),
                ],
                const SizedBox(height: 24),
                Text('Lampiran', style: theme.textTheme.titleMedium),
                if (task.attachments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Tambahkan foto, PDF, atau tautan melalui Edit tugas.',
                    ),
                  ),
                for (final a in task.attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      a.isLink ? Icons.link : Icons.description_outlined,
                    ),
                    title: Text(a.name),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => AppActions.run(
                      context,
                      () => AttachmentService.open(a),
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Hapus tugas',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          await AppActions.deleteTask(
                            context,
                            provider,
                            subject,
                            task,
                          );
                          if (context.mounted &&
                              provider
                                      .getSubjectById(subjectId)
                                      ?.tasks
                                      .any((t) => t.id == taskId) !=
                                  true) {
                            Navigator.pop(context);
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
