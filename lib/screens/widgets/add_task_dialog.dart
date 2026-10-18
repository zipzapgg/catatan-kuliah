import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/task_item.dart';
import '../../utils/app_actions.dart';
import '../../utils/deadline_helper.dart';
import 'app_widgets.dart';
import 'schedule_fields.dart';
import '../../models/task_attachment.dart';
import '../../models/academic_schedule.dart';
import '../../services/attachment_service.dart';

class AddTaskDialog extends StatefulWidget {
  final TaskItem? initialTask;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  const AddTaskDialog({super.key, this.initialTask, this.onSave});
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    TaskItem? initialTask,
    Future<void> Function(Map<String, dynamic>)? onSave,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: false,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      builder: (_) => AddTaskDialog(initialTask: initialTask, onSave: onSave),
    );
  }

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _deadline;
  final _step = TextEditingController();
  late List<SubTask> _steps;
  late String _priority;
  bool _saving = false;
  int _sequence = 0;
  late final TextEditingController _description;
  final _link = TextEditingController();
  late String _status, _kind;
  late int _repeatDays;
  int? _deadlineMinutes;
  late List<int> _reminders;
  late List<TaskAttachment> _attachments;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTask?.title);
    _deadline = TextEditingController(text: widget.initialTask?.deadline);
    _steps = List.of(widget.initialTask?.subTasks ?? []);
    _priority = widget.initialTask?.priority ?? 'normal';
    _description = TextEditingController(text: widget.initialTask?.description);
    _status = widget.initialTask?.status ?? 'todo';
    _kind = widget.initialTask?.kind ?? 'task';
    _repeatDays = widget.initialTask?.repeatDays ?? 0;
    _deadlineMinutes = widget.initialTask?.deadlineMinutes;
    _reminders = List.of(widget.initialTask?.reminderMinutes ?? [1440, 60]);
    _attachments = List.of(widget.initialTask?.attachments ?? []);
  }

  @override
  void dispose() {
    _title.dispose();
    _deadline.dispose();
    _step.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final existing = DeadlineHelper.parseDate(_deadline.text);
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 10);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          existing != null &&
              !existing.isBefore(first) &&
              !existing.isAfter(last)
          ? existing
          : now,
      firstDate: first,
      lastDate: last,
      helpText: 'Pilih deadline',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null && mounted) {
      setState(() {
        _deadline.text = DeadlineHelper.normalize(
          picked.toIso8601String().split('T').first,
        )!;
      });
    }
  }

  void _addStep() {
    if (_step.text.trim().isEmpty) return;
    setState(() {
      _steps.add(
        SubTask(
          id: 'step_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}',
          title: _step.text.trim(),
        ),
      );
      _step.clear();
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_step.text.trim().isNotEmpty) _addStep();
    final values = <String, dynamic>{
      'title': _title.text.trim(),
      'deadline': DeadlineHelper.normalize(_deadline.text),
      'priority': _priority,
      'subTasks': _steps,
      'deadlineMinutes': _deadlineMinutes,
      'reminderMinutes': _reminders,
      'status': _status,
      'kind': _kind,
      'description': _description.text.trim(),
      'repeatDays': _repeatDays,
      'attachments': _attachments,
    };
    if (_repeatDays != 0 && DeadlineHelper.parseDate(_deadline.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal deadline untuk tugas berulang.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final success =
        widget.onSave == null ||
        await AppActions.run(context, () => widget.onSave!(values));
    if (mounted) {
      setState(() => _saving = false);
      if (success) Navigator.pop(context, values);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        child: FormSheet(
          title: widget.initialTask == null ? 'Tugas baru' : 'Edit tugas',
          subtitle:
              'Catat yang perlu dikerjakan, lalu pecah menjadi langkah kecil.',
          busy: _saving,
          children: [
            TextFormField(
              controller: _title,
              autofocus: widget.initialTask == null,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Judul tugas',
                hintText: 'Apa yang perlu diselesaikan?',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Judul tugas wajib diisi'
                  : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _deadline,
              enabled: !_saving,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Deadline (opsional)',
                hintText: 'Tanggal atau keterangan, mis. Sebelum UTS',
                suffixIcon: IconButton(
                  tooltip: 'Pilih tanggal',
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in ['Hari ini', 'Besok', 'Minggu ini'])
                  ActionChip(
                    label: Text(preset),
                    onPressed: _saving
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _deadline.text = DeadlineHelper.normalize(
                                preset,
                              )!,
                            );
                          },
                  ),
                if (_deadline.text.isNotEmpty)
                  ActionChip(
                    label: const Text('Tanpa deadline'),
                    onPressed: _saving ? null : () => setState(_deadline.clear),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DeadlineHelper.parseDate(_deadline.text) == null
                  ? 'Pengingat otomatis memerlukan tanggal. Keterangan tetap bisa disimpan.'
                  : 'Aktifkan izin melalui menu Pengingat. Tanpa jam, deadline dianggap pukul 23.59.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (DeadlineHelper.parseDate(_deadline.text) != null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  _deadlineMinutes == null
                      ? 'Atur jam deadline · 23:59'
                      : 'Deadline · ${(_deadlineMinutes! ~/ 60).toString().padLeft(2, '0')}:${(_deadlineMinutes! % 60).toString().padLeft(2, '0')}',
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: (_deadlineMinutes ?? 1439) ~/ 60,
                            minute: (_deadlineMinutes ?? 1439) % 60,
                          ),
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          ),
                        );
                        if (time != null && mounted) {
                          setState(
                            () =>
                                _deadlineMinutes = time.hour * 60 + time.minute,
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              Text('Pengingat', style: theme.textTheme.titleMedium),
              ReminderChoices(
                value: _reminders,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _reminders = v),
              ),
              const SizedBox(height: 20),
            ],
            Text('Prioritas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in {
                  'normal': 'Normal',
                  'high': 'Penting',
                  'low': 'Rendah',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _priority == entry.key,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _priority = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Detail & pengulangan'),
              subtitle: Text(
                '${TaskItem.kinds[_kind]} · ${TaskItem.statuses[_status]}',
              ),
              maintainState: true,
              children: [
                Text('Jenis kegiatan', style: theme.textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in TaskItem.kinds.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _kind == entry.key,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _kind = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status pengerjaan',
                  ),
                  items: [
                    for (final entry in TaskItem.statuses.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _repeatDays,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pengulangan tugas',
                  ),
                  items: [
                    for (final entry in {
                      0: 'Tidak berulang',
                      1: 'Setiap hari',
                      7: 'Setiap minggu',
                      14: 'Setiap 2 minggu',
                    }.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _repeatDays = v!),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tugas berikutnya dibuat setelah ditandai terkumpul. Jadwal tetap mengikuti tanggal awal.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Instruksi / deskripsi (opsional)',
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Foto, PDF & tautan'),
              subtitle: Text('${_attachments.length} lampiran'),
              maintainState: true,
              children: [
                Text('Lampiran', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Foto atau PDF maksimal 10 MB per berkas, hingga 10 lampiran. Berkas disimpan di perangkat ini.',
                  style: theme.textTheme.bodySmall,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Pilih foto atau PDF'),
                  onPressed: _saving || _attachments.length >= 10
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await AppActions.run(context, () async {
                            final picked = await AttachmentService.pick();
                            if (picked != null && mounted) {
                              setState(() => _attachments.add(picked));
                            }
                          });
                          if (mounted) setState(() => _saving = false);
                        },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _link,
                  enabled: !_saving && _attachments.length < 10,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Tautan materi / pengumpulan',
                    hintText: 'https://...',
                    suffixIcon: IconButton(
                      tooltip: 'Tambahkan tautan',
                      icon: const Icon(Icons.add_link),
                      onPressed: _saving || _attachments.length >= 10
                          ? null
                          : () {
                              final value = _link.text.trim();
                              if (!isWebLink(value)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Masukkan tautan http:// atau https:// yang valid.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                _attachments.add(
                                  TaskAttachment(
                                    id: 'link_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}',
                                    name: Uri.parse(value).host,
                                    url: value,
                                  ),
                                );
                                _link.clear();
                              });
                            },
                    ),
                  ),
                ),
                for (final attachment in _attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      attachment.isLink
                          ? Icons.link
                          : Icons.description_outlined,
                    ),
                    title: Text(attachment.name),
                    onTap: () => AppActions.run(
                      context,
                      () => AttachmentService.open(attachment),
                    ),
                    trailing: IconButton(
                      tooltip: 'Lepas lampiran ${attachment.name}',
                      icon: const Icon(Icons.close),
                      onPressed: _saving
                          ? null
                          : () =>
                                setState(() => _attachments.remove(attachment)),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
            const SizedBox(height: 20),
            Text('Langkah pengerjaan', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Opsional. Tambahkan bagian kecil dari tugasmu.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _step,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tambah langkah',
                hintText: 'Mis. cari referensi',
                suffixIcon: IconButton(
                  tooltip: 'Tambah langkah',
                  onPressed: _saving ? null : _addStep,
                  icon: const Icon(Icons.add),
                ),
              ),
              onSubmitted: (_) => _addStep(),
            ),
            for (int i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      _steps[i].isDone
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _steps[i].title,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus langkah',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _steps.removeAt(i)),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 20),
                label: Text(
                  _saving
                      ? 'Menyimpan...'
                      : widget.initialTask == null
                      ? 'Tambah tugas'
                      : 'Simpan perubahan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
