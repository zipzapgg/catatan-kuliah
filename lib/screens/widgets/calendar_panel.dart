import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/academic_schedule.dart';
import '../../models/unpam_calendar.dart';
import '../document_import_screen.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_actions.dart';
import '../task_detail_screen.dart';
import '../subject_detail_screen.dart';
import 'mentari_card.dart';
import 'app_widgets.dart';
import 'payments_sheet.dart';

class CalendarPanel extends StatefulWidget {
  final AppProvider provider;
  const CalendarPanel({super.key, required this.provider});
  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  DateTime selected = calendarDay(DateTime.now());
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  AppProvider get provider => widget.provider;

  Future<void> _unpam() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ListenableBuilder(
      listenable: provider,
      builder: (ctx, _) => FormSheet(
        title: UnpamCalendar.semester,
        subtitle:
            'Acuan kalender akademik dari kampus. Tanggal dapat disesuaikan jika ada perubahan.',
        busy: provider.isSaving,
        children: [
          const Text(
            'UTS: 19–24 Oktober 2026\nUAS: 14–19 Desember 2026\nAwal Reg. A/B: 31 Agustus 2026\nAkhir semester: 5–6 Februari 2027',
          ),
          const SizedBox(height: 16),
          const Text(
            'Terapkan untuk mata kuliah aktif yang belum memiliki semester dan mata kuliah UNPAM Gasal 2026/2027. Dua batas bayaran Reg. A/B juga ditambahkan; nominal dan status dibayar perlu kamu isi.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Terapkan kalender UNPAM'),
            onPressed: provider.isSaving
                ? null
                : () async {
                    final success = await AppActions.run(
                      ctx,
                      provider.applyUnpamCalendar,
                    );
                    if (success && ctx.mounted) {
                      Navigator.pop(ctx);
                      provider.setSemester(UnpamCalendar.semester);
                    }
                  },
          ),
          const SizedBox(height: 12),
          const Text(
            'Tanggal susulan, herregistrasi, libur akhir tahun, revisi KRS, dan awal semester genap tampil sebagai informasi di kalender. Libur Mentari mengikuti pekan UTS/UAS utama.',
          ),
        ],
      ),
    ),
  );

  Future<void> _exams() async {
    if (provider.semesters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan mata kuliah dan semester terlebih dahulu.'),
        ),
      );
      return;
    }
    var semester = provider.semester ?? provider.semesters.last;
    var breaks = List<ExamBreak>.of(provider.breaksForSemester(semester));
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !saving,
          child: FormSheet(
            title: 'Periode UTS & UAS',
            subtitle:
                'Mentari libur selama ujian. Pertemuan yang beririsan dilewati tanpa menggeser jadwal selanjutnya.',
            busy: saving,
            children: [
              DropdownButtonFormField<String>(
                initialValue: semester,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: [
                  for (final s in provider.semesters)
                    DropdownMenuItem(
                      value: s,
                      child: Text(s.isEmpty ? 'Tanpa semester' : s),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (v) => update(() {
                        semester = v!;
                        breaks = List.of(provider.breaksForSemester(semester));
                      }),
              ),
              const SizedBox(height: 20),
              for (final name in ['UTS', 'UAS']) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text(
                    breaks.any((b) => b.name == name)
                        ? breaks
                              .where((b) => b.name == name)
                              .map(
                                (b) =>
                                    '${DateFormat('d MMM', 'id').format(b.start)} – ${DateFormat('d MMM yyyy', 'id').format(b.end)}',
                              )
                              .first
                        : 'Belum diatur',
                  ),
                  trailing: IconButton(
                    tooltip: 'Hapus periode $name',
                    icon: const Icon(Icons.close),
                    onPressed: saving
                        ? null
                        : () => update(
                            () => breaks.removeWhere((b) => b.name == name),
                          ),
                  ),
                  onTap: saving
                      ? null
                      : () async {
                          final previous = breaks
                              .where((b) => b.name == name)
                              .firstOrNull;
                          final range = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            helpText: 'Periode $name',
                            saveText: 'Simpan',
                            initialDateRange: previous == null
                                ? null
                                : DateTimeRange(
                                    start: previous.start,
                                    end: previous.end,
                                  ),
                          );
                          if (range != null && ctx.mounted) {
                            update(() {
                              breaks.removeWhere((b) => b.name == name);
                              breaks.add(
                                ExamBreak(
                                  name: name,
                                  start: range.start,
                                  end: range.end,
                                ),
                              );
                            });
                          }
                        },
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() => saving = true);
                        final success = await AppActions.run(
                          ctx,
                          () => provider.setExamBreaks(semester, breaks),
                        );
                        if (!ctx.mounted) return;
                        if (success) {
                          Navigator.pop(ctx);
                          if (mounted) setState(() {});
                        } else {
                          update(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Menyimpan...' : 'Simpan periode ujian'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = provider.visibleSubjects;
    final usesUnpam = subjects.any((s) => s.semester == UnpamCalendar.semester);
    final customEvents = provider.visibleEvents;
    final academicEvents =
        usesUnpam &&
            !customEvents.any(
              (e) => e.semester == UnpamCalendar.semester && e.kind == 'event',
            )
        ? UnpamCalendar.eventsOn(selected)
        : <String>[];
    academicEvents.addAll(
      customEvents
          .where((e) => e.kind == 'event' && e.contains(selected))
          .map((e) => e.title),
    );
    final payments = provider.visiblePayments
        .where((p) => p.dueAt != null && dateKey(p.dueAt!) == dateKey(selected))
        .toList();
    final tasks = provider
        .getAllTasksWithSubject()
        .where(
          (e) =>
              e.task.dueAt != null &&
              dateKey(e.task.dueAt!) == dateKey(selected),
        )
        .toList();
    final occurrences = [
      for (final s in subjects)
        if (s.mentari != null)
          for (final o in s.mentari!.occurrences(
            from: selected,
            to: shiftDays(
              selected,
              1,
            ).subtract(const Duration(microseconds: 1)),
            breaks: s.examBreaks,
          ))
            (subject: s, occurrence: o),
    ];
    final exams = <String, ExamBreak>{
      for (final s in subjects)
        for (final b in s.examBreaks)
          if (b.contains(selected)) '${s.semester}:${b.name}': b,
      for (final e in customEvents)
        if (e.kind != 'event' && e.contains(selected))
          '${e.semester}:${e.kind}': ExamBreak(
            name: e.kind,
            start: e.start,
            end: e.end,
          ),
    };
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final classes = subjects
        .where((s) => s.scheduleDay == days[selected.weekday - 1])
        .toList();
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final blanks = month.weekday - 1;
    final marked = <String>{};
    marked.addAll(
      provider.visiblePayments
          .where((p) => p.dueAt != null)
          .map((p) => dateKey(p.dueAt!)),
    );
    if (usesUnpam) {
      for (var day = 1; day <= totalDays; day++) {
        final date = DateTime(month.year, month.month, day);
        if (UnpamCalendar.eventsOn(date).isNotEmpty) marked.add(dateKey(date));
      }
    }
    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      if (customEvents.any((e) => e.contains(date))) marked.add(dateKey(date));
    }
    for (final e in provider.getAllTasksWithSubject()) {
      if (e.task.dueAt != null) marked.add(dateKey(e.task.dueAt!));
    }
    for (final s in subjects) {
      if (s.mentari != null) {
        for (final o in s.mentari!.occurrences(
          from: month,
          to: DateTime(month.year, month.month + 1),
          breaks: s.examBreaks,
        )) {
          marked.add(dateKey(o.start));
          marked.add(dateKey(o.deadline));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kalender',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hari ini',
                    onPressed: () => setState(() {
                      selected = calendarDay(DateTime.now());
                      month = DateTime(selected.year, selected.month);
                    }),
                    icon: const Icon(Icons.today_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: provider.isSaving
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DocumentImportScreen(provider: provider),
                        ),
                      ),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Impor PDF / gambar'),
              ),
              TextButton.icon(
                onPressed: provider.isSaving ? null : _unpam,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Kalender UNPAM Gasal 2026/2027'),
              ),
              TextButton.icon(
                onPressed: () => PaymentsSheet.show(context, provider),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Bayaran & cicilan'),
              ),
              OutlinedButton.icon(
                onPressed: provider.isSaving ? null : _exams,
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Atur UTS / UAS · Libur Mentari'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Bulan sebelumnya',
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy', 'id').format(month),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bulan berikutnya',
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month + 1),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final day in ['S', 'S', 'R', 'K', 'J', 'S', 'M'])
                    Expanded(
                      child: Center(
                        child: Text(day, style: theme.textTheme.bodySmall),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (ctx, constraints) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: MediaQuery.textScalerOf(ctx).scale(1) > 1.4
                        ? 68
                        : 52,
                  ),
                  itemCount: ((totalDays + blanks) / 7).ceil() * 7,
                  itemBuilder: (ctx, index) {
                    final number = index - blanks + 1;
                    if (number < 1 || number > totalDays) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(month.year, month.month, number);
                    final chosen = date == selected;
                    final isExam =
                        customEvents.any(
                          (e) => e.kind != 'event' && e.contains(date),
                        ) ||
                        subjects.any(
                          (s) => s.examBreaks.any((b) => b.contains(date)),
                        );
                    return Semantics(
                      label:
                          '${DateFormat('EEEE d MMMM', 'id').format(date)}${isExam ? ', periode ujian' : ''}',
                      selected: chosen,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => selected = date),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: chosen
                                ? theme.colorScheme.primary
                                : isExam
                                ? theme.colorScheme.surfaceContainerHighest
                                : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$number',
                                style: TextStyle(
                                  fontWeight: chosen
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: chosen
                                      ? theme.colorScheme.onPrimary
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: marked.contains(dateKey(date))
                                      ? chosen
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Titik: kegiatan / bayaran · Latar abu-abu: periode ujian',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SectionHeading(
          title: DateFormat('EEEE, d MMMM', 'id').format(selected),
          subtitle:
              '${tasks.length} kegiatan · ${classes.length} kelas · ${occurrences.length} Mentari',
        ),
        for (final entry in exams.entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '${entry.value.name} · Mentari libur pada periode ini',
              style: theme.textTheme.titleSmall,
            ),
          ),
        for (final title in academicEvents)
          Card(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(title),
              subtitle: const Text('Kalender akademik'),
            ),
          ),
        for (final payment in payments)
          Card(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: ListTile(
              leading: Icon(
                payment.isPaid
                    ? Icons.check_circle_outline
                    : Icons.account_balance_wallet_outlined,
              ),
              title: Text(payment.title),
              subtitle: Text(
                payment.isPaid ? 'Sudah dibayar' : 'Belum ditandai dibayar',
              ),
              onTap: () =>
                  PaymentsSheet.edit(context, provider, payment: payment),
            ),
          ),
        for (final subject in classes)
          Card(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: const Icon(Icons.school_outlined),
              title: Text(subject.name),
              subtitle: Text(
                '${subject.scheduleTime ?? 'Jam belum diatur'}${subject.room == null ? '' : ' · ${subject.room}'}',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SubjectDetailScreen(
                    provider: provider,
                    subjectId: subject.id,
                  ),
                ),
              ),
            ),
          ),
        for (final entry in tasks)
          Card(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: Icon(
                entry.task.isDone
                    ? Icons.check_circle_outline
                    : Icons.assignment_outlined,
              ),
              title: Text(entry.task.title),
              subtitle: Text(
                '${entry.subject.name} · ${entry.task.timeLabel.isEmpty ? '23:59' : entry.task.timeLabel}',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TaskDetailScreen(
                    provider: provider,
                    subjectId: entry.subject.id,
                    taskId: entry.task.id,
                  ),
                ),
              ),
            ),
          ),
        for (final entry in occurrences)
          MentariCard(
            subject: entry.subject,
            occurrence: entry.occurrence,
            provider: provider,
          ),
        if (tasks.isEmpty &&
            classes.isEmpty &&
            occurrences.isEmpty &&
            academicEvents.isEmpty &&
            payments.isEmpty &&
            exams.isEmpty)
          const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Hari yang lapang',
            message:
                'Tidak ada kelas, deadline, atau Mentari pada tanggal ini.',
          ),
      ],
    );
  }
}
