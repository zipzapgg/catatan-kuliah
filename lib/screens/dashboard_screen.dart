import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/academic_schedule.dart';
import '../services/notification_service.dart';
import 'widgets/calendar_panel.dart';
import 'document_import_screen.dart';
import 'widgets/payments_sheet.dart';
import 'widgets/mentari_card.dart';
import 'task_detail_screen.dart';
import 'package:flutter/services.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_actions.dart';
import '../utils/deadline_helper.dart';
import 'subject_detail_screen.dart';
import 'widgets/add_subject_dialog.dart';
import 'widgets/add_task_dialog.dart';
import 'widgets/app_widgets.dart';
import 'widgets/subject_card.dart';
import 'widgets/task_tile.dart';

class DashboardScreen extends StatefulWidget {
  final AppProvider provider;
  final int initialTab;
  const DashboardScreen({
    super.key,
    required this.provider,
    this.initialTab = 0,
  });
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  String _filter = 'pending';
  String _taskQuery = '';
  final _taskSearch = TextEditingController();
  final _subjectSearch = TextEditingController();
  AppProvider get provider => widget.provider;
  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    NotificationService().opened.addListener(_notification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notification());
  }

  Future<void> _notification() async {
    final service = NotificationService();
    final payload = service.opened.value;
    if (payload == null) return;
    service.opened.value = null;
    await provider.waitUntilReady();
    if (!mounted) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['payment'] is String) {
        final payment = provider.payments
            .where((p) => p.id == data['payment'])
            .firstOrNull;
        if (payment != null) {
          provider.setSemester(payment.semester);
          await PaymentsSheet.show(context, provider);
        }
        return;
      }
      final subject = provider.getSubjectById(data['subject'] as String);
      if (subject == null) return;
      final task = subject.tasks.where((t) => t.id == data['task']).firstOrNull;
      if (task != null) {
        _openTask(subject, task);
      } else {
        _openSubject(subject);
      }
    } on FormatException {
      return;
    } on TypeError {
      return;
    }
  }

  void _openTask(Subject subject, TaskItem task) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => TaskDetailScreen(
        provider: provider,
        subjectId: subject.id,
        taskId: task.id,
      ),
    ),
  );

  @override
  void dispose() {
    _taskSearch.dispose();
    _subjectSearch.dispose();
    NotificationService().opened.removeListener(_notification);
    super.dispose();
  }

  void _openSubject(Subject subject) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          SubjectDetailScreen(provider: provider, subjectId: subject.id),
    ),
  );

  Future<void> _subjectForm([Subject? subject]) async {
    await AddSubjectDialog.show(
      context,
      initialSubject: subject,
      onSave: (data) => subject == null
          ? provider.addSubject(
              data['name'] as String,
              data['colorValue'] as int,
              scheduleDay: data['scheduleDay'] as String?,
              scheduleTime: data['scheduleTime'] as String?,
              room: data['room'] as String?,
              lecturer: data['lecturer'] as String?,
              semester: data['semester'] as String,
              mentari: data['mentari'],
            )
          : provider.updateSubject(
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

  Future<void> _newTask() async {
    final subjects = provider.subjects.where((s) => !s.isArchived).toList();
    if (subjects.isEmpty) {
      await _subjectForm();
      if (!mounted) return;
      if (provider.activeSubjectCount == 0) return;
      return _newTask();
    }
    Subject? selected;
    if (subjects.length == 1) {
      selected = subjects.first;
    } else {
      selected = await showModalBottomSheet<Subject>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (ctx) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tugas untuk mata kuliah apa?',
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup pilihan mata kuliah',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    'Pilih satu mata kuliah untuk melanjutkan.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: subjects.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 20, endIndent: 20, height: 1),
                    itemBuilder: (_, index) {
                      final subject = subjects[index];
                      return ListTile(
                        key: ValueKey('choose-${subject.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 12,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(subject.colorValue),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        title: Text(subject.name),
                        subtitle: Text(
                          '${subject.pendingTasks} tugas belum selesai',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(ctx, subject),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (selected != null && mounted) await _taskForm(selected);
  }

  Future<void> _export() => AppActions.run(
    context,
    () => Clipboard.setData(ClipboardData(text: provider.exportData())),
    success:
        'Cadangan JSON disalin. Foto/PDF tetap di perangkat ini; tautan ikut dicadangkan.',
  );

  Future<void> _import() async {
    final input = TextEditingController();
    bool saving = false;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            title: const Text('Pulihkan cadangan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pemulihan mengganti semua data saat ini, termasuk arsip dan bayaran. Cadangan lama yang belum memuat bayaran akan mengosongkan daftar bayaran. Salin cadangan data saat ini sebelum melanjutkan.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: input,
                  enabled: !saving,
                  maxLines: 7,
                  minLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Data cadangan JSON',
                    hintText: 'Tempel cadangan di sini',
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (input.text.trim().isEmpty) {
                          setDialogState(
                            () =>
                                error = 'Tempel data cadangan terlebih dahulu.',
                          );
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        bool valid = false;
                        final success = await AppActions.run(ctx, () async {
                          valid = await provider.importData(input.text.trim());
                        });
                        if (!ctx.mounted) return;
                        if (success && valid) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cadangan dipulihkan.'),
                              ),
                            );
                          }
                        } else {
                          setDialogState(() {
                            saving = false;
                            error = success
                                ? 'Cadangan tidak valid. Periksa format, ID, dan hubungan mata kuliahnya.'
                                : 'Pemulihan belum tersimpan. Data saat ini tetap tersedia.';
                          });
                        }
                      },
                child: Text(saving ? 'Memulihkan...' : 'Ganti dan pulihkan'),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    input.dispose();
  }

  void _menu(String value) {
    switch (value) {
      case 'document':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DocumentImportScreen(provider: provider),
          ),
        );
      case 'export':
        _export();
      case 'import':
        _import();
      case 'reminders':
        AppActions.run(
          context,
          provider.enableReminders,
          success:
              'Pengingat diaktifkan untuk tugas bertanggal. Waktu pengiriman mengikuti pengaturan HP.',
        );
      case 'test':
        AppActions.run(
          context,
          provider.testSendNotification,
          success: 'Permintaan notifikasi tes dikirim.',
        );
    }
  }

  Widget _search(
    TextEditingController controller,
    String hint,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: TextField(
      controller: controller,
      onChanged: changed,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                onPressed: () {
                  controller.clear();
                  changed('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
    ),
  );

  Widget _focusPanel(List<({TaskItem task, Subject subject})> all) {
    final pending = all.where((e) => !e.task.isDone).length;
    final completed = all.length - pending;
    final urgent = all
        .where(
          (e) =>
              !e.task.isDone && DeadlineHelper.parse(e.task.deadline).isUrgent,
        )
        .length;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rencana belajarmu',
            style: TextStyle(color: Color(0xFFCED0D6), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            '$pending tugas aktif',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 30,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            urgent > 0
                ? '$urgent tugas perlu perhatian hari ini.'
                : pending > 0
                ? 'Selesaikan satu langkah, lalu lanjutkan.'
                : 'Semua tugas sudah dituntaskan.',
            style: const TextStyle(color: Color(0xFFE1E2E6), height: 1.4),
          ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              label: '$completed dari ${all.length} tugas selesai',
              child: LinearProgressIndicator(
                value: completed / all.length,
                minHeight: 4,
                borderRadius: BorderRadius.circular(3),
                color: Colors.white,
                backgroundColor: const Color(0xFF45464C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$completed dari ${all.length} selesai',
              style: const TextStyle(color: Color(0xFFCED0D6), fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.ink,
                  shape: const StadiumBorder(),
                ),
                onPressed: provider.isSaving ? null : _newTask,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah tugas'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF292B30),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => setState(() => _tab = 2),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('Kalender'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _homeSlivers() {
    final all = provider.getAllTasksWithSubject();
    final now = DateTime.now();
    final upcoming = [
      for (final s in provider.visibleSubjects)
        if (s.mentari != null)
          for (final o in s.mentari!.occurrences(
            from: shiftDays(calendarDay(now), -14),
            to: shiftDays(now, 14),
            breaks: s.examBreaks,
          ))
            if (!o.isDone) (subject: s, occurrence: o),
    ]..sort((a, b) => a.occurrence.deadline.compareTo(b.occurrence.deadline));
    final pending = all.where((e) => !e.task.isDone).take(3).toList();
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEDEEF2),
                foregroundColor: AppTheme.ink,
                radius: 24,
                child: Icon(Icons.school_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      now.hour < 11
                          ? 'Selamat pagi.'
                          : now.hour < 15
                          ? 'Selamat siang.'
                          : now.hour < 18
                          ? 'Selamat sore.'
                          : 'Selamat malam.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM', 'id').format(now),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Aktifkan pengingat',
                icon: const Icon(Icons.notifications_none_outlined),
                onPressed: () => _menu('reminders'),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(child: _focusPanel(all)),
      SliverToBoxAdapter(
        child: Card(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Bayaran & cicilan'),
            subtitle: Text(
              provider.visiblePayments.isEmpty
                  ? 'Tanggal bayar dan pengingat angsuran'
                  : '${provider.visiblePayments.where((p) => !p.isPaid).length} belum ditandai dibayar',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PaymentsSheet.show(context, provider),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeading(
          title: 'E-learning Mentari',
          subtitle: 'Pertemuan dan deadline terdekat',
          action: TextButton(
            onPressed: () => setState(() => _tab = 2),
            child: const Text('Lihat semua'),
          ),
        ),
      ),
      if (upcoming.isEmpty)
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.visibleSubjects.any((s) => s.mentari != null)
                        ? 'Tidak ada Mentari dalam dua minggu ini.'
                        : 'Atur ritme e-learning-mu.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Jadwal mingguan atau dua mingguan, dengan jeda otomatis saat UTS dan UAS.',
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _tab = 3),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Atur mata kuliah'),
                  ),
                ],
              ),
            ),
          ),
        ),
      for (final e in upcoming.take(2))
        SliverToBoxAdapter(
          child: MentariCard(
            subject: e.subject,
            occurrence: e.occurrence,
            provider: provider,
          ),
        ),
      SliverToBoxAdapter(
        child: SectionHeading(
          title: 'Berikutnya dikerjakan',
          action: TextButton(
            onPressed: () => setState(() => _tab = 1),
            child: const Text('Semua tugas'),
          ),
        ),
      ),
      if (pending.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Belum ada tugas aktif. Tambahkan dari tombol di atas.',
            ),
          ),
        ),
      for (final e in pending)
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: const Icon(Icons.assignment_outlined),
              title: Text(e.task.title),
              subtitle: Text(
                '${e.subject.name}\n${DeadlineHelper.display(e.task.deadline)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTask(e.subject, e.task),
            ),
          ),
        ),
    ];
  }

  Widget _semesterFilter() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: 'Pilih semester',
        onSelected: (v) => provider.setSemester(v == '__all__' ? null : v),
        itemBuilder: (_) => [
          const PopupMenuItem(value: '__all__', child: Text('Semua semester')),
          for (final s in provider.semesters)
            PopupMenuItem(
              value: s,
              child: Text(s.isEmpty ? 'Tanpa semester' : s),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  provider.semester == null
                      ? 'Semua semester'
                      : provider.semester!.isEmpty
                      ? 'Tanpa semester'
                      : provider.semester!,
                ),
              ),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _taskSlivers() {
    final all = provider.getAllTasksWithSubject();
    final entries = provider.getAllTasksWithSubject(
      filter: _filter,
      query: _taskQuery,
    );
    final counts = {
      'all': all.length,
      'pending': all.where((e) => !e.task.isDone).length,
      'high': all
          .where((e) => !e.task.isDone && e.task.priority == 'high')
          .length,
      'completed': all.where((e) => e.task.isDone).length,
    };
    const labels = {
      'pending': 'Belum selesai',
      'all': 'Semua',
      'high': 'Penting',
      'completed': 'Selesai',
    };
    return [
      const SliverToBoxAdapter(
        child: SectionHeading(
          title: 'Tugasmu',
          subtitle: 'Satu langkah lebih dekat ke selesai.',
        ),
      ),
      SliverToBoxAdapter(
        child: _search(
          _taskSearch,
          'Cari tugas atau mata kuliah',
          (value) => setState(() => _taskQuery = value),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${entry.value} ${counts[entry.key]}'),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeading(
          title: _taskQuery.isNotEmpty
              ? 'Hasil pencarian'
              : _filter == 'completed'
              ? 'Sudah dituntaskan'
              : 'Daftar tugas',
          subtitle: _filter == 'completed'
              ? 'Tugas yang selesai tetap bisa diedit atau dihapus.'
              : 'Prioritas tinggi dulu, lalu deadline terdekat.',
        ),
      ),
      if (entries.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: _taskQuery.isNotEmpty
                ? Icons.search_off
                : _filter == 'completed'
                ? Icons.task_alt
                : Icons.checklist_outlined,
            title: _taskQuery.isNotEmpty
                ? 'Tugas tidak ditemukan'
                : _filter == 'completed'
                ? 'Belum ada tugas selesai'
                : _filter == 'high'
                ? 'Tidak ada tugas penting'
                : 'Semua terasa lebih ringan',
            message: _taskQuery.isNotEmpty
                ? 'Coba kata lain atau bersihkan pencarian.'
                : _filter == 'completed'
                ? 'Tandai tugas yang sudah kamu tuntaskan.'
                : _filter == 'high'
                ? 'Tugas prioritas tinggi akan muncul di sini.'
                : 'Tambahkan tugas baru untuk mulai menyusun rencana belajarmu.',
            action: _taskQuery.isEmpty && _filter == 'pending'
                ? 'Tambah tugas'
                : null,
            onAction:
                _taskQuery.isEmpty && _filter == 'pending' && !provider.isSaving
                ? _newTask
                : null,
          ),
        )
      else
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (_, index) {
            final entry = entries[index];
            return TaskTile(
              key: ValueKey(entry.task.id),
              task: entry.task,
              busy: provider.isSaving,
              subjectName: entry.subject.name,
              subjectColor: Color(entry.subject.colorValue),
              onToggle: (_) => AppActions.run(
                context,
                () =>
                    provider.toggleTaskStatus(entry.subject.id, entry.task.id),
              ),
              onToggleSubTask: (id) => AppActions.run(
                context,
                () =>
                    provider.toggleSubTask(entry.subject.id, entry.task.id, id),
              ),
              onEdit: () => _taskForm(entry.subject, entry.task),
              onOpen: () => _openTask(entry.subject, entry.task),
              onDelete: () => AppActions.deleteTask(
                context,
                provider,
                entry.subject,
                entry.task,
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _subjectSlivers() {
    final subjects = provider.filteredSubjects;
    const sortLabels = {
      SortOption.byPendingTasks: 'Tugas tersisa',
      SortOption.byRecent: 'Terbaru',
      SortOption.byName: 'Nama A–Z',
    };
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mata kuliah',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                '${provider.activeSubjectCount} mata kuliah aktif. Tugas, catatan, dan jadwal tersimpan dalam satu tempat.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _search(
          _subjectSearch,
          'Cari mata kuliah, tugas, catatan',
          provider.setSearchQuery,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text('Arsip ${provider.archivedSubjectCount}'),
                selected: provider.showArchived,
                onSelected: provider.setShowArchived,
              ),
              PopupMenuButton<SortOption>(
                tooltip: 'Urutkan mata kuliah',
                onSelected: provider.setSortOption,
                itemBuilder: (_) => [
                  for (final entry in sortLabels.entries)
                    CheckedPopupMenuItem(
                      value: entry.key,
                      checked: provider.sortOption == entry.key,
                      child: Text(entry.value),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 8),
                      Text(sortLabels[provider.sortOption]!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeading(
          title: provider.showArchived ? 'Arsip mata kuliah' : 'Mata kuliahmu',
          subtitle: '${subjects.length} mata kuliah ditampilkan',
        ),
      ),
      if (subjects.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: provider.showArchived
                ? Icons.archive_outlined
                : Icons.menu_book_outlined,
            title: provider.searchQuery.isNotEmpty
                ? 'Mata kuliah tidak ditemukan'
                : provider.showArchived
                ? 'Arsip masih kosong'
                : 'Mulai semester baru',
            message: provider.searchQuery.isNotEmpty
                ? 'Coba nama mata kuliah, tugas, atau isi catatan.'
                : provider.showArchived
                ? 'Arsipkan mata kuliah yang sudah selesai tanpa kehilangan catatannya.'
                : 'Tambahkan mata kuliah untuk menyimpan tugas dan catatan.',
            action: !provider.showArchived && provider.searchQuery.isEmpty
                ? 'Tambah mata kuliah'
                : null,
            onAction:
                !provider.showArchived &&
                    provider.searchQuery.isEmpty &&
                    !provider.isSaving
                ? _subjectForm
                : null,
          ),
        )
      else
        SliverList.builder(
          itemCount: subjects.length,
          itemBuilder: (_, index) {
            final subject = subjects[index];
            return SubjectCard(
              subject: subject,
              busy: provider.isSaving,
              onTap: () => _openSubject(subject),
              onEdit: () => _subjectForm(subject),
              onArchive: () => AppActions.run(
                context,
                () => provider.toggleArchiveSubject(subject.id),
                success: subject.isArchived
                    ? 'Mata kuliah dikeluarkan dari arsip.'
                    : 'Mata kuliah diarsipkan.',
              ),
              onDelete: () =>
                  AppActions.deleteSubject(context, provider, subject),
            );
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: provider,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Text(
            'Catatan Kuliah',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            IconButton(
              tooltip: provider.isDarkMode
                  ? 'Gunakan tema terang'
                  : 'Gunakan tema gelap',
              onPressed: () => AppActions.run(context, provider.toggleDarkMode),
              icon: Icon(
                provider.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Pengaturan dan cadangan',
              onSelected: _menu,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'document',
                  enabled:
                      !provider.isLoading &&
                      !provider.isSaving &&
                      !provider.hasLoadError,
                  child: const Text('Impor PDF / gambar'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'export',
                  enabled: !provider.isLoading && !provider.hasLoadError,
                  child: const Text('Salin cadangan JSON'),
                ),
                PopupMenuItem(
                  value: 'import',
                  enabled: !provider.isSaving,
                  child: const Text('Pulihkan cadangan JSON'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'reminders',
                  child: Text('Aktifkan pengingat'),
                ),
                const PopupMenuItem(
                  value: 'test',
                  child: Text('Tes notifikasi'),
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
            child: provider.isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Membuka catatanmu...'),
                      ],
                    ),
                  )
                : CustomScrollView(
                    key: ValueKey('dashboard-$_tab'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (provider.hasLoadError)
                        SliverToBoxAdapter(
                          child: EmptyState(
                            icon: Icons.folder_off_outlined,
                            title: 'Data belum dapat dibuka',
                            message: provider.loadError!,
                            action: 'Pulihkan cadangan',
                            onAction: _import,
                          ),
                        ),
                      if (provider.hasLoadError)
                        SliverToBoxAdapter(
                          child: Center(
                            child: TextButton.icon(
                              onPressed: provider.loadData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba muat ulang'),
                            ),
                          ),
                        )
                      else ...[
                        if (provider.reminderError != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Text(
                                provider.reminderError!,
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          ),
                        if (provider.semesters.isNotEmpty)
                          SliverToBoxAdapter(child: _semesterFilter()),
                        ...switch (_tab) {
                          0 => _homeSlivers(),
                          1 => _taskSlivers(),
                          2 => [
                            SliverToBoxAdapter(
                              child: CalendarPanel(provider: provider),
                            ),
                          ],
                          _ => _subjectSlivers(),
                        },
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
          ),
        ),
        floatingActionButton:
            provider.isLoading || provider.hasLoadError || _tab == 0
            ? null
            : FloatingActionButton.extended(
                tooltip: _tab == 3 ? 'Tambah mata kuliah' : 'Tambah tugas',
                onPressed: provider.isSaving
                    ? null
                    : _tab == 3
                    ? _subjectForm
                    : _newTask,
                icon: const Icon(Icons.add),
                label: Text(_tab == 3 ? 'Mata kuliah' : 'Tugas baru'),
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: NavigationBar(
                    height: MediaQuery.textScalerOf(context).scale(1) > 1.4
                        ? 106
                        : 76,
                    selectedIndex: _tab,
                    onDestinationSelected: (value) {
                      FocusScope.of(context).unfocus();
                      setState(() => _tab = value);
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Beranda',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.checklist_outlined),
                        selectedIcon: Icon(Icons.checklist),
                        label: 'Tugas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: 'Kalender',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: 'Mata kuliah',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '© 2026 Ghalbi',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: .3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
