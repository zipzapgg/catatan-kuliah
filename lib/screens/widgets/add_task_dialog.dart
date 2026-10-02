import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/task_item.dart';
import '../../utils/app_actions.dart';
import '../../utils/deadline_helper.dart';
import 'app_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTask?.title);
    _deadline = TextEditingController(text: widget.initialTask?.deadline);
    _steps = List.of(widget.initialTask?.subTasks ?? []);
    _priority = widget.initialTask?.priority ?? 'normal';
  }

  @override
  void dispose() {
    _title.dispose();
    _deadline.dispose();
    _step.dispose();
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
    };
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
                  : 'Pengingat sekitar pukul 08.00 pada hari deadline. Aktifkan melalui menu Pengingat.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
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
