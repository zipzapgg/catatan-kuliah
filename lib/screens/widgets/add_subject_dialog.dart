import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_actions.dart';
import 'app_widgets.dart';

class AddSubjectDialog extends StatefulWidget {
  final Subject? initialSubject;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  const AddSubjectDialog({super.key, this.initialSubject, this.onSave});
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Subject? initialSubject,
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
      builder: (_) =>
          AddSubjectDialog(initialSubject: initialSubject, onSave: onSave),
    );
  }

  @override
  State<AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<AddSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _time, _room, _lecturer;
  late int _color;
  String? _day;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final subject = widget.initialSubject;
    _name = TextEditingController(text: subject?.name);
    _time = TextEditingController(text: subject?.scheduleTime);
    _room = TextEditingController(text: subject?.room);
    _lecturer = TextEditingController(text: subject?.lecturer);
    _color = subject?.colorValue ?? AppTheme.subjectColors.first.toARGB32();
    _day = subject?.scheduleDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    _room.dispose();
    _lecturer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final values = <String, dynamic>{
      'name': _name.text.trim(),
      'colorValue': _color,
      'scheduleDay': _day,
      'scheduleTime': _time.text.trim(),
      'room': _room.text.trim(),
      'lecturer': _lecturer.text.trim(),
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

  Future<void> _pickTimes() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Jam mulai',
      cancelText: 'Batal',
      confirmText: 'Lanjut',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (start.hour + 2).clamp(0, 23),
        minute: start.minute,
      ),
      helpText: 'Jam selesai',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (end == null || !mounted) return;
    String format(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() => _time.text = '${format(start)} - ${format(end)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const colorNames = [
      'Biru',
      'Hijau',
      'Ungu',
      'Kuning',
      'Merah',
      'Toska',
      'Indigo',
      'Jingga',
      'Abu-abu',
    ];
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        child: FormSheet(
          title: widget.initialSubject == null
              ? 'Mata kuliah baru'
              : 'Edit mata kuliah',
          subtitle: 'Satu tempat untuk tugas, catatan, dan jadwal perkuliahan.',
          busy: _saving,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              autofocus: widget.initialSubject == null,
              textCapitalization: TextCapitalization.words,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Nama mata kuliah',
                hintText: 'Masukkan nama mata kuliah',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama mata kuliah wajib diisi'
                  : null,
            ),
            const SizedBox(height: 24),
            Text('Warna penanda', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < AppTheme.subjectColors.length; i++)
                  Semantics(
                    button: true,
                    selected: _color == AppTheme.subjectColors[i].toARGB32(),
                    label: 'Warna ${colorNames[i]}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _saving
                          ? null
                          : () => setState(
                              () =>
                                  _color = AppTheme.subjectColors[i].toARGB32(),
                            ),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppTheme.subjectColors[i],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                _color == AppTheme.subjectColors[i].toARGB32()
                                ? Icon(
                                    Icons.check,
                                    color:
                                        AppTheme.subjectColors[i]
                                                .computeLuminance() >
                                            .35
                                        ? AppTheme.ink
                                        : Colors.white,
                                    size: 22,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Jadwal kuliah', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Opsional. Jadwal akan tampil di tab Jadwal.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final day in [
                  'Senin',
                  'Selasa',
                  'Rabu',
                  'Kamis',
                  'Jumat',
                  'Sabtu',
                  'Minggu',
                ])
                  ChoiceChip(
                    label: Text(day),
                    selected: _day == day,
                    onSelected: _saving
                        ? null
                        : (selected) =>
                              setState(() => _day = selected ? day : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _time,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Jam kuliah (opsional)',
                hintText: '08:00 - 10:30',
                suffixIcon: IconButton(
                  tooltip: 'Pilih jam kuliah',
                  onPressed: _saving ? null : _pickTimes,
                  icon: const Icon(Icons.schedule_outlined),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _room,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Ruangan (opsional)',
                hintText: 'Nama atau nomor ruangan',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lecturer,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Dosen (opsional)',
                hintText: 'Nama dosen pengampu',
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
                      : widget.initialSubject == null
                      ? 'Tambah mata kuliah'
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
