import 'package:flutter/material.dart';
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
  const DashboardScreen({super.key, required this.provider});
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
  void dispose() {
    _taskSearch.dispose();
    _subjectSearch.dispose();
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
            )
          : provider.updateSubject(
              subject.id,
              data['name'] as String,
              data['colorValue'] as int,
              newScheduleDay: data['scheduleDay'] as String?,
              newScheduleTime: data['scheduleTime'] as String?,
              newRoom: data['room'] as String?,
              newLecturer: data['lecturer'] as String?,
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
            )
          : provider.updateTask(
              subject.id,
              task.id,
              data['title'] as String,
              newDeadline: data['deadline'] as String?,
              newPriority: data['priority'] as String,
              newSubTasks: data['subTasks'] as List<SubTask>,
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
        'Cadangan JSON disalin. Simpan di tempat aman agar bisa dipulihkan.',
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
                  'Pemulihan mengganti semua data saat ini, termasuk arsip. Salin cadangan data saat ini sebelum melanjutkan.',
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
    final pending = all.where((entry) => !entry.task.isDone).toList();
    final urgent = pending
        .where((entry) => DeadlineHelper.parse(entry.task.deadline).isUrgent)
        .length;
    final completed = all.length - pending.length;
    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}',
            style: const TextStyle(color: Color(0xFFC0D7CA), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            pending.isEmpty
                ? 'Ruang untuk bernapas.'
                : '${pending.length} tugas\nmenunggu langkahmu.',
            style: const TextStyle(
              fontSize: 28,
              height: 1.16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: Color(0xFFF6FAF5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pending.isEmpty
                ? all.isEmpty
                      ? 'Tambahkan tugas pertamamu dan susun semester ini.'
                      : 'Semua tugas aktif sudah selesai. Kerja bagus!'
                : urgent > 0
                ? '$urgent tugas mendekati atau melewati deadline.'
                : 'Mulai satu per satu. Setiap langkah berarti.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFFE0EBE2),
            ),
          ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 20),
            Semantics(
              label: '$completed dari ${all.length} tugas selesai',
              child: LinearProgressIndicator(
                value: completed / all.length,
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFFA5D5B3),
                backgroundColor: const Color(0xFF3B5B4B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completed dari ${all.length} tugas selesai',
              style: const TextStyle(fontSize: 12, color: Color(0xFFC0D7CA)),
            ),
          ],
        ],
      ),
    );
  }

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
      SliverToBoxAdapter(child: _focusPanel(all)),
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
                'Semester,\nlebih tertata.',
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

  List<Widget> _scheduleSlivers() {
    final groups = provider.subjectsByDay;
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final today = days[DateTime.now().weekday - 1];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ritme minggu ini.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Hari ini $today. Susun waktu kuliah dan siapkan tugas sebelum kelas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      if (groups.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'Jadwal masih kosong',
            message: 'Isi hari dan jam kuliah saat menambahkan mata kuliah.',
            action: 'Tambah mata kuliah',
            onAction: provider.isSaving ? null : _subjectForm,
          ),
        ),
      for (final group in groups.entries) ...[
        SliverToBoxAdapter(
          child: SectionHeading(
            title: group.key == today ? '${group.key} · Hari ini' : group.key,
            subtitle: '${group.value.length} mata kuliah',
          ),
        ),
        SliverList.builder(
          itemCount: group.value.length,
          itemBuilder: (_, index) {
            final subject = group.value[index];
            final theme = Theme.of(context);
            return Card(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openSubject(subject),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(subject.colorValue),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.scheduleTime?.isNotEmpty == true
                                  ? subject.scheduleTime!
                                  : 'Jam belum diatur',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subject.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (subject.room != null ||
                                subject.lecturer != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                [
                                  subject.room,
                                  subject.lecturer,
                                ].whereType<String>().join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${subject.pendingTasks} tugas belum selesai',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
                        ...switch (_tab) {
                          0 => _taskSlivers(),
                          1 => _subjectSlivers(),
                          _ => _scheduleSlivers(),
                        },
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
          ),
        ),
        floatingActionButton: provider.isLoading || provider.hasLoadError
            ? null
            : FloatingActionButton.extended(
                tooltip: _tab == 0 ? 'Tambah tugas' : 'Tambah mata kuliah',
                onPressed: provider.isSaving
                    ? null
                    : _tab == 0
                    ? _newTask
                    : _subjectForm,
                icon: const Icon(Icons.add),
                label: Text(_tab == 0 ? 'Tugas baru' : 'Mata kuliah'),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) {
            FocusScope.of(context).unfocus();
            setState(() => _tab = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Tugas',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Mata kuliah',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Jadwal',
            ),
          ],
        ),
      );
    },
  );
}
