import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../models/note_item.dart';
import '../providers/app_provider.dart';
import '../utils/app_actions.dart';
import 'widgets/add_subject_dialog.dart';
import 'widgets/add_task_dialog.dart';
import 'widgets/add_note_dialog.dart';
import 'widgets/app_widgets.dart';
import 'widgets/task_tile.dart';
import 'widgets/note_card.dart';
import 'widgets/mentari_card.dart';
import '../models/academic_schedule.dart';
import 'task_detail_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final AppProvider provider;
  final String subjectId;
  const SubjectDetailScreen({
    super.key,
    required this.provider,
    required this.subjectId,
  });
  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  String _filter = 'all';
  AppProvider get provider => widget.provider;

  Future<void> _editSubject(Subject subject) async {
    await AddSubjectDialog.show(
      context,
      initialSubject: subject,
      onSave: (data) => provider.updateSubject(
        subject.id,
        data['name'] as String,
        data['colorValue'] as int,
        newScheduleDay: data['scheduleDay'] as String?,
        newScheduleTime: data['scheduleTime'] as String?,
        newRoom: data['room'] as String?,
        newLecturer: data['lecturer'] as String?,
        newSemester: data['semester'] as String,
        newMentari: data['mentari'],
      ),
    );
  }

  Future<void> _taskForm(Subject subject, [TaskItem? task]) async {
    await AddTaskDialog.show(
      context,
      initialTask: task,
      onSave: (data) => task == null
          ? provider.addTask(
              subject.id,
              data['title'] as String,
              deadline: data['deadline'] as String?,
              priority: data['priority'] as String,
              subTasks: data['subTasks'] as List<SubTask>,
              details: data,
            )
          : provider.updateTask(
              subject.id,
              task.id,
              data['title'] as String,
              newDeadline: data['deadline'] as String?,
              newPriority: data['priority'] as String,
              newSubTasks: data['subTasks'] as List<SubTask>,
              details: data,
            ),
    );
  }

  Future<void> _noteForm(Subject subject, [NoteItem? note]) async {
    await AddNoteDialog.show(
      context,
      initialNote: note,
      onSave: (data) => note == null
          ? provider.addNote(subject.id, data['content'] as String)
          : provider.updateNote(subject.id, note.id, data['content'] as String),
    );
  }

  Future<void> _menu(String value, Subject subject) async {
    switch (value) {
      case 'edit':
        await _editSubject(subject);
      case 'share':
        await AppActions.run(
          context,
          () => Clipboard.setData(
            ClipboardData(text: provider.formatSubjectForSharing(subject)),
          ),
          success: 'Ringkasan mata kuliah disalin.',
        );
      case 'archive':
        await AppActions.run(
          context,
          () => provider.toggleArchiveSubject(subject.id),
          success: subject.isArchived
              ? 'Mata kuliah dikeluarkan dari arsip.'
              : 'Mata kuliah diarsipkan.',
        );
      case 'delete':
        final deleted = await AppActions.deleteSubject(
          context,
          provider,
          subject,
        );
        if (deleted && mounted) Navigator.pop(context);
    }
  }

  Widget _summary(Subject subject) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = [
      if (subject.scheduleDay != null) subject.scheduleDay!,
      if (subject.scheduleTime != null) subject.scheduleTime!,
      if (subject.room != null) 'Ruang ${subject.room}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Color(subject.colorValue),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text(subject.name, style: theme.textTheme.headlineMedium),
          if (subject.semester.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(subject.semester, style: theme.textTheme.bodySmall),
            ),
          if (subject.lecturer != null) ...[
            const SizedBox(height: 8),
            Text(subject.lecturer!, style: theme.textTheme.bodyMedium),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    details.join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (subject.isArchived) ...[
            const SizedBox(height: 16),
            Text(
              'Mata kuliah diarsipkan. Pengingat tugas dinonaktifkan sampai dikeluarkan dari arsip.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.totalTasks == 0
                      ? 'Siap untuk tugas pertama'
                      : '${subject.pendingTasks} tugas belum selesai',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subject.totalTasks == 0
                      ? 'Pecah tugas besar menjadi langkah kecil agar lebih mudah dikerjakan.'
                      : '${subject.completedTasks} dari ${subject.totalTasks} tugas sudah dituntaskan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                if (subject.totalTasks > 0) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    label:
                        '${subject.completedTasks} dari ${subject.totalTasks} tugas selesai',
                    child: LinearProgressIndicator(
                      value: subject.progressPercentage,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: colors.surface,
                      color: colors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: provider,
    builder: (context, _) {
      final subject = provider.getSubjectById(widget.subjectId);
      if (subject == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Mata kuliah')),
          body: const Center(
            child: EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Mata kuliah sudah dihapus',
              message: 'Kembali ke daftar untuk membuka mata kuliah lain.',
            ),
          ),
        );
      }
      final tasks = subject.tasks
          .where(
            (task) =>
                _filter == 'all' ||
                _filter == 'pending' && !task.isDone ||
                _filter == 'completed' && task.isDone,
          )
          .toList();
      TaskTile tile(TaskItem task, int index) => TaskTile(
        key: ValueKey(task.id),
        task: task,
        busy: provider.isSaving,
        showDragHandle: _filter == 'all',
        dragIndex: index,
        onToggle: (_) => AppActions.run(
          context,
          () => provider.toggleTaskStatus(subject.id, task.id),
        ),
        onToggleSubTask: (id) => AppActions.run(
          context,
          () => provider.toggleSubTask(subject.id, task.id, id),
        ),
        onEdit: () => _taskForm(subject, task),
        onOpen: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(
              provider: provider,
              subjectId: subject.id,
              taskId: task.id,
            ),
          ),
        ),
        onDelete: () => AppActions.deleteTask(context, provider, subject, task),
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Mata kuliah',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Opsi mata kuliah',
              enabled: !provider.isSaving,
              onSelected: (value) => _menu(value, subject),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit mata kuliah'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Salin ringkasan'),
                ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          bottom: provider.isSaving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _summary(subject)),
                if (subject.mentari != null) ...[
                  SliverToBoxAdapter(
                    child: SectionHeading(
                      title: 'Mentari',
                      subtitle:
                          'Setiap ${subject.mentari!.intervalWeeks == 1 ? 'minggu' : '2 minggu'} · Libur saat UTS/UAS',
                    ),
                  ),
                  for (final occurrence in subject.mentari!.occurrences(
                    from: shiftDays(calendarDay(DateTime.now()), -28),
                    to: shiftDays(DateTime.now(), 42),
                    breaks: subject.examBreaks,
                  ))
                    SliverToBoxAdapter(
                      child: MentariCard(
                        subject: subject,
                        occurrence: occurrence,
                        provider: provider,
                      ),
                    ),
                ],
                SliverToBoxAdapter(
                  child: SectionHeading(
                    title: 'Tugas',
                    subtitle: _filter == 'all' && subject.totalTasks > 1
                        ? 'Seret pegangan untuk mengubah urutan.'
                        : 'Selesaikan, edit, atau hapus tugas satu per satu.',
                    action: IconButton(
                      tooltip: 'Tambah tugas',
                      onPressed: provider.isSaving
                          ? null
                          : () => _taskForm(subject),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in {
                          'all': 'Semua ${subject.totalTasks}',
                          'pending': 'Belum ${subject.pendingTasks}',
                          'completed': 'Selesai ${subject.completedTasks}',
                        }.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                      ],
                    ),
                  ),
                ),
                if (tasks.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.checklist_outlined,
                      title: _filter == 'all'
                          ? 'Belum ada tugas'
                          : _filter == 'pending'
                          ? 'Semua tugas selesai'
                          : 'Belum ada tugas selesai',
                      message: _filter == 'all'
                          ? 'Tambahkan tugas pertama. Mata kuliah tetap tersimpan saat tugas dihapus.'
                          : _filter == 'pending'
                          ? 'Kamu bisa melihat tugas yang sudah selesai melalui filter Semua.'
                          : 'Tugas yang kamu tandai selesai akan muncul di sini.',
                    ),
                  )
                else if (_filter == 'all')
                  SliverReorderableList(
                    itemCount: tasks.length,
                    onReorder: (oldIndex, newIndex) => AppActions.run(
                      context,
                      () =>
                          provider.reorderTasks(subject.id, oldIndex, newIndex),
                    ),
                    itemBuilder: (_, index) => tile(tasks[index], index),
                  )
                else
                  SliverList.builder(
                    itemCount: tasks.length,
                    itemBuilder: (_, index) => tile(tasks[index], index),
                  ),
                SliverToBoxAdapter(
                  child: SectionHeading(
                    title: 'Catatan',
                    subtitle: 'Pengumuman, materi, dan hal yang perlu diingat.',
                    action: IconButton(
                      tooltip: 'Tambah catatan',
                      onPressed: provider.isSaving
                          ? null
                          : () => _noteForm(subject),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
                if (subject.notes.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OutlinedButton.icon(
                        onPressed: provider.isSaving
                            ? null
                            : () => _noteForm(subject),
                        icon: const Icon(Icons.note_add_outlined, size: 20),
                        label: const Text('Tulis catatan pertama'),
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: subject.notes.length,
                    itemBuilder: (_, index) {
                      final note = subject.notes[index];
                      return NoteCard(
                        key: ValueKey(note.id),
                        note: note,
                        busy: provider.isSaving,
                        onEdit: () => _noteForm(subject, note),
                        onDelete: () => AppActions.deleteNote(
                          context,
                          provider,
                          subject,
                          note,
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          tooltip: 'Tambah tugas',
          onPressed: provider.isSaving ? null : () => _taskForm(subject),
          icon: const Icon(Icons.add),
          label: const Text('Tugas baru'),
        ),
      );
    },
  );
}
