import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/academic_schedule.dart';
import '../../models/unpam_calendar.dart';

String dateTimeLabel(DateTime value) =>
    DateFormat('d MMM yyyy, HH:mm', 'id').format(value);

class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime>? onChanged;
  final bool withTime;
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.withTime = true,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: Icon(
      withTime ? Icons.event_outlined : Icons.date_range_outlined,
      size: 20,
    ),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$label\n${withTime ? dateTimeLabel(value) : DateFormat('d MMM yyyy', 'id').format(value)}',
      ),
    ),
    onPressed: onChanged == null
        ? null
        : () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              helpText: label,
              cancelText: 'Batal',
              confirmText: 'Pilih',
            );
            if (date == null || !context.mounted) return;
            var time = TimeOfDay.fromDateTime(value);
            if (withTime) {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
                helpText: label,
                cancelText: 'Batal',
                confirmText: 'Pilih',
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked == null) return;
              time = picked;
            }
            onChanged!(
              DateTime(
                date.year,
                date.month,
                date.day,
                withTime ? time.hour : 0,
                withTime ? time.minute : 0,
              ),
            );
          },
  );
}

class ReminderChoices extends StatelessWidget {
  final List<int> value;
  final ValueChanged<List<int>>? onChanged;
  const ReminderChoices({super.key, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final entry in {
        4320: 'H-3',
        1440: 'H-1',
        60: '1 jam',
        0: 'Saat deadline',
      }.entries)
        FilterChip(
          label: Text(entry.value),
          selected: value.contains(entry.key),
          onSelected: onChanged == null
              ? null
              : (selected) => onChanged!([
                  ...value.where((v) => v != entry.key),
                  if (selected) entry.key,
                ]),
        ),
      if (value.any((v) => ![4320, 1440, 60, 0].contains(v)))
        InputChip(
          label: const Text('Pengingat lama'),
          onDeleted: onChanged == null
              ? null
              : () => onChanged!(
                  value.where([4320, 1440, 60, 0].contains).toList(),
                ),
        ),
    ],
  );
}

class MentariEditor extends StatefulWidget {
  final MentariSchedule? initialValue;
  final String semester;
  final ValueChanged<MentariSchedule?> onChanged;
  final bool enabled;
  const MentariEditor({
    super.key,
    this.initialValue,
    this.semester = '',
    required this.onChanged,
    this.enabled = true,
  });
  @override
  State<MentariEditor> createState() => _MentariEditorState();
}

class _MentariEditorState extends State<MentariEditor> {
  late bool active;
  late DateTime start, deadline, until;
  late int weeks;
  late List<int> reminders;
  late final TextEditingController url;
  @override
  void initState() {
    super.initState();
    final s = widget.initialValue;
    active = s != null;
    _defaultDates();
    start = s?.firstStart ?? start;
    deadline = s?.firstDeadline ?? deadline;
    until = s?.until ?? until;
    weeks = s?.intervalWeeks ?? 2;
    reminders = List.of(s?.reminderMinutes ?? [1440, 60]);
    url = TextEditingController(text: s?.url);
  }

  void _defaultDates() {
    final today = widget.semester == UnpamCalendar.semester
        ? UnpamCalendar.start
        : calendarDay(DateTime.now());
    start = DateTime(today.year, today.month, today.day, 8);
    deadline = DateTime(today.year, today.month, today.day + 6, 23, 59);
    until = widget.semester == UnpamCalendar.semester
        ? UnpamCalendar.mentariEnd
        : shiftDays(today, 16 * 7);
  }

  @override
  void didUpdateWidget(covariant MentariEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!active &&
        widget.initialValue == null &&
        oldWidget.semester != widget.semester) {
      _defaultDates();
    }
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  void changed() => widget.onChanged(
    active
        ? MentariSchedule(
            firstStart: start,
            firstDeadline: deadline,
            until: until,
            intervalWeeks: weeks,
            url: url.text.trim(),
            reminderMinutes: reminders,
            completed: widget.initialValue?.completed ?? [],
          )
        : null,
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('E-learning Mentari'),
        subtitle: const Text('Jadwal rutin, deadline, dan pengingat'),
        value: active,
        onChanged: widget.enabled
            ? (value) {
                setState(() => active = value);
                changed();
              }
            : null,
      ),
      if (active) ...[
        if (widget.semester == UnpamCalendar.semester)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Acuan UNPAM: awal Reg. A/B 31 Agustus, Mentari hingga 13 Desember sebelum UAS. Sesuaikan pertemuan pertama dengan kelasmu; batas akhir tetap bisa diubah.',
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final w in [1, 2])
              ChoiceChip(
                label: Text(w == 1 ? 'Setiap minggu' : 'Setiap 2 minggu'),
                selected: weeks == w,
                onSelected: widget.enabled
                    ? (_) {
                        setState(() => weeks = w);
                        changed();
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        DateTimeField(
          label: 'Pertemuan pertama dibuka',
          value: start,
          onChanged: !widget.enabled
              ? null
              : (v) {
                  setState(() {
                    start = v;
                    if (!deadline.isAfter(v)) deadline = shiftDays(v, 6);
                    if (until.isBefore(v)) until = shiftDays(v, 112);
                  });
                  changed();
                },
        ),
        const SizedBox(height: 10),
        DateTimeField(
          label: 'Deadline pertemuan pertama',
          value: deadline,
          onChanged: !widget.enabled
              ? null
              : (v) {
                  setState(() => deadline = v);
                  changed();
                },
        ),
        const SizedBox(height: 10),
        DateTimeField(
          label: 'Tanggal akhir perkuliahan',
          value: until,
          withTime: false,
          onChanged: !widget.enabled
              ? null
              : (v) {
                  setState(() => until = v);
                  changed();
                },
        ),
        const SizedBox(height: 12),
        Text(
          'Tanggal dibuka dan deadline berikutnya berulang setiap ${weeks * 7} hari. Periode UTS/UAS diatur di Kalender; pertemuan yang beririsan akan dilewati.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: url,
          enabled: widget.enabled,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Tautan kelas Mentari (opsional)',
            hintText: 'https://...',
          ),
          onChanged: (_) => changed(),
          validator: (v) =>
              v != null && v.trim().isNotEmpty && !isWebLink(v.trim())
              ? 'Masukkan tautan http:// atau https://'
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          'Pengingat sebelum deadline',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ReminderChoices(
          value: reminders,
          onChanged: !widget.enabled
              ? null
              : (v) {
                  setState(() => reminders = v);
                  changed();
                },
        ),
        Text(
          'Notifikasi juga dikirim saat pertemuan dibuka. Aktifkan izin pengingat di menu Pengingat.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}
