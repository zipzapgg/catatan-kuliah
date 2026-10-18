import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic_event.dart';
import '../models/document_draft.dart';
import '../models/subject.dart';
import '../models/tuition_payment.dart';
import '../models/unpam_calendar.dart';
import '../providers/app_provider.dart';
import '../services/document_reader.dart';
import '../services/document_parser.dart';
import '../utils/app_actions.dart';
import 'widgets/app_widgets.dart';
import 'widgets/payments_sheet.dart';
import 'widgets/schedule_fields.dart';

Subject? matchImportedSubject(
  Subject incoming,
  List<Subject> current,
  String semester,
) {
  final available = current
      .where(
        (s) => !s.isArchived && (s.semester == semester || s.semester.isEmpty),
      )
      .toList();
  final exact = available
      .where((s) => importName(s.name) == importName(incoming.name))
      .toList();
  if (exact.length == 1) return exact.single;
  final tokens = importName(incoming.name).split(' ').toSet();
  final close = available.where((s) {
    final old = importName(s.name).split(' ').toSet();
    return tokens.intersection(old).length / tokens.union(old).length >= .65;
  }).toList();
  return close.length == 1 ? close.single : null;
}

class DocumentImportScreen extends StatefulWidget {
  final AppProvider provider;
  final DocumentDraft? initialDraft;
  const DocumentImportScreen({
    super.key,
    required this.provider,
    this.initialDraft,
  });
  @override
  State<DocumentImportScreen> createState() => _DocumentImportScreenState();
}

class _DocumentImportScreenState extends State<DocumentImportScreen> {
  final _subjects = <Subject>[];
  final _payments = <TuitionPayment>[];
  final _events = <AcademicEvent>[];
  final _warnings = <String>[];
  final _sources = <String, String>{};
  final _selected = <String>{};
  final _needsReview = <String>{};
  final _groupReview = <String>{};
  StudyGroup _studyGroup = StudyGroup.a;
  bool _groupChosen = false;
  final _targets = <String, String>{};
  final _files = <String>[];
  late final TextEditingController _semester;
  DocumentKind _kind = DocumentKind.automatic;
  String? _progress;
  bool _saving = false, _cancelled = false;
  AppProvider get provider => widget.provider;
  bool get _busy => _progress != null || _saving;

  @override
  void initState() {
    super.initState();
    _semester = TextEditingController(
      text: provider.semester ?? UnpamCalendar.semester,
    );
    if (widget.initialDraft != null) _merge(widget.initialDraft!);
  }

  @override
  void dispose() {
    _cancelled = true;
    _semester.dispose();
    super.dispose();
  }

  void _merge(DocumentDraft draft) {
    if (!_groupChosen && draft.studyGroup != null) {
      _studyGroup = draft.studyGroup!;
      _groupChosen = true;
    }
    if (_files.isEmpty) _semester.text = draft.semester;
    if (draft.semester != _semester.text) {
      _warnings.add(
        '${draft.fileName}: semester berbeda; periksa semester tujuan.',
      );
    }
    _files.add(draft.fileName);
    for (final s in draft.subjects) {
      _subjects.removeWhere((x) => x.id == s.id);
      _subjects.add(s);
    }
    for (final p in draft.payments) {
      final old = _oldPayment(p);
      final calendar = p.id.startsWith('calendar_payment_');
      _payments.removeWhere((x) => x.id == p.id);
      _payments.add(
        p.copyWith(
          dueAt: p.dueAt ?? old?.dueAt,
          amount: p.amount ?? old?.amount,
          isPaid: calendar ? old?.isPaid ?? p.isPaid : p.isPaid,
          paidAt: calendar ? old?.paidAt ?? p.paidAt : p.paidAt,
        ),
      );
      if (p.dueAt == null && old?.dueAt != null) {
        _warnings.add(
          'Jatuh tempo yang pernah kamu isi dipertahankan pada tagihan yang cocok.',
        );
      }
      if (!calendar && old?.isPaid == true && !p.isPaid) {
        _needsReview.add(p.id);
        _warnings.add(
          '${p.title}: sebelumnya ditandai lunas, tetapi dokumen menyatakan belum lunas. Periksa sebelum memilih baris ini.',
        );
      }
    }
    for (final e in draft.events) {
      _events.removeWhere((x) => x.id == e.id);
      _events.add(e);
    }
    final ids = [
      ...draft.subjects.map((s) => s.id),
      ...draft.payments.map((p) => p.id),
      ...draft.events.map((e) => e.id),
    ];
    _selected.addAll(ids.where((id) => !draft.needsReview.contains(id)));
    _needsReview.addAll(draft.needsReview);
    _selected.removeAll(_needsReview);
    _sources.addAll(draft.sources);
    _warnings.addAll(draft.warnings);
    _checkGroup();
  }

  void _checkGroup() {
    _groupReview
      ..clear()
      ..addAll(
        DocumentDraft(
          fileName: '',
          semester: _semester.text,
          subjects: _subjects,
          payments: _payments,
          events: _events,
        ).reviewForGroup(_studyGroup),
      );
    _selected.removeAll(_groupReview);
  }

  Future<void> _pick() async {
    _cancelled = false;
    try {
      final file = await DocumentReader.pick();
      if (file == null || !mounted) return;
      setState(() => _progress = 'Membuka ${file.name}');
      final pages = await DocumentReader().read(
        file,
        cancelled: () => _cancelled,
        onProgress: (text) {
          if (mounted) setState(() => _progress = text);
        },
      );
      if (!mounted || _cancelled) return;
      final draft = DocumentParser().parse(
        file.name,
        pages,
        kind: _kind,
        fallbackSemester: _semester.text.trim(),
      );
      setState(() => _merge(draft));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Dokumen belum bisa dibuka. Coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Subject? _target(Subject s) {
    if (_targets.containsKey(s.id)) {
      return provider.getSubjectById(_targets[s.id]!);
    }
    return matchImportedSubject(s, provider.subjects, _semester.text.trim());
  }

  TuitionPayment? _oldPayment(TuitionPayment p) {
    final id = provider.payments.where((old) => old.id == p.id).firstOrNull;
    if (id != null) return id;
    if (p.id.startsWith('bill_')) return null;
    if (p.id.startsWith('calendar_payment_') &&
        _semester.text.trim() == UnpamCalendar.semester &&
        RegExp(
          r'reg(?:uler)?\.?\s*a\s*[&/]\s*b\b',
          caseSensitive: false,
        ).hasMatch(p.title)) {
      final presets = UnpamCalendar.payments.where(
        (old) => RegExp(
          '\\b${old.id.endsWith('uts') ? 'UTS' : 'UAS'}\\b',
          caseSensitive: false,
        ).hasMatch(p.title),
      );
      if (presets.length == 1) {
        final old = provider.payments
            .where((old) => old.id == presets.single.id)
            .firstOrNull;
        if (old != null) return old;
      }
    }
    final matches = provider.payments
        .where(
          (old) =>
              old.semester == _semester.text.trim() &&
              importName(old.title) == importName(p.title),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _apply() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_semester.text.trim().isEmpty || _semester.text.trim().length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi semester tujuan terlebih dahulu.')),
      );
      return;
    }
    final semester = _semester.text.trim();
    final subjects = [
      for (final s in _subjects.where((s) => _selected.contains(s.id)))
        s.copyWith(
          id:
              _target(s)?.id ??
              'import_${importName(semester)}_${importName(s.name)}',
          semester: semester,
        ),
    ];
    final payments = [
      for (final p in _payments.where((p) => _selected.contains(p.id)))
        p.copyWith(id: _oldPayment(p)?.id ?? p.id, semester: semester),
    ];
    final events = <AcademicEvent>[];
    for (final e in _events.where((e) => _selected.contains(e.id))) {
      final existing = provider.events
          .where(
            (old) =>
                old.semester == semester &&
                (e.kind != 'event'
                    ? old.kind == e.kind
                    : importName(old.title) == importName(e.title)),
          )
          .toList();
      events.add(
        AcademicEvent(
          id: existing.length == 1 ? existing.single.id : e.id,
          title: e.title,
          semester: semester,
          start: e.start,
          end: e.end,
          kind: e.kind,
        ),
      );
    }
    if (subjects.map((s) => s.id).toSet().length != subjects.length ||
        payments.map((p) => p.id).toSet().length != payments.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ada dua baris menuju data yang sama. Pilih satu baris atau ubah pencocokannya.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final success = await AppActions.run(
      context,
      () => provider.applyDocument(
        subjects: subjects,
        payments: payments,
        events: events,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      provider.setSemester(semester);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${subjects.length} mata kuliah, ${payments.length} bayaran, ${events.length} kegiatan diterapkan.',
          ),
        ),
      );
    }
  }

  Future<void> _editSubject(Subject subject) async {
    var name = subject.name, time = subject.scheduleTime ?? '';
    var lecturer = subject.lecturer ?? '', room = subject.room ?? '';
    var day = subject.scheduleDay ?? 'Senin';
    final key = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => Form(
          key: key,
          child: FormSheet(
            title: 'Periksa mata kuliah',
            subtitle: 'Perubahan disimpan setelah kamu menerapkan impor.',
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (v) => name = v,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Mata kuliah'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Hari'),
                items: [
                  for (final d in [
                    'Senin',
                    'Selasa',
                    'Rabu',
                    'Kamis',
                    'Jumat',
                    'Sabtu',
                    'Minggu',
                  ])
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => update(() => day = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: time,
                onChanged: (v) => time = v,
                decoration: const InputDecoration(
                  labelText: 'Jam',
                  hintText: '07:10 - 08:50',
                ),
                validator: (v) =>
                    RegExp(
                      r'^([01]\d|2[0-3]):[0-5]\d\s*-\s*([01]\d|2[0-3]):[0-5]\d$',
                    ).hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Gunakan HH:mm - HH:mm',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: lecturer,
                onChanged: (v) => lecturer = v,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Dosen'),
              ),
              TextFormField(
                initialValue: room,
                onChanged: (v) => room = v,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Ruang'),
              ),
              FilledButton(
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  setState(
                    () => _subjects[_subjects.indexOf(subject)] = subject
                        .copyWith(
                          name: name.trim(),
                          scheduleDay: day,
                          scheduleTime: time.trim(),
                          lecturer: lecturer.trim(),
                          room: room.trim(),
                        ),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Simpan koreksi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editEvent(AcademicEvent event) async {
    var title = event.title;
    var start = event.start, end = event.end, kind = event.kind;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => FormSheet(
          title: 'Periksa kegiatan',
          subtitle: 'Pekan UTS/UAS akan meliburkan Mentari.',
          children: [
            TextFormField(
              initialValue: title,
              onChanged: (v) => title = v,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Kegiatan'),
            ),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: const [
                DropdownMenuItem(value: 'event', child: Text('Kegiatan biasa')),
                DropdownMenuItem(value: 'UTS', child: Text('Pekan UTS')),
                DropdownMenuItem(value: 'UAS', child: Text('Pekan UAS')),
              ],
              onChanged: (v) => update(() => kind = v!),
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Mulai',
              value: start,
              withTime: false,
              onChanged: (v) => update(() {
                start = v;
                if (end.isBefore(start)) end = start;
              }),
            ),
            DateTimeField(
              label: 'Selesai',
              value: end,
              withTime: false,
              onChanged: (v) => update(() => end = v),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            FilledButton(
              onPressed: () {
                final next = AcademicEvent(
                  id: event.id,
                  title: title.trim(),
                  semester: _semester.text.trim(),
                  start: start,
                  end: end,
                  kind: kind,
                );
                try {
                  next.validate();
                } on FormatException catch (e) {
                  update(() => error = e.message);
                  return;
                }
                setState(() => _events[_events.indexOf(event)] = next);
                Navigator.pop(ctx);
              },
              child: const Text('Simpan koreksi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String id,
    String title,
    String detail,
    VoidCallback edit, {
    Widget? extra,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: _selected.contains(id),
            title: Text(title),
            subtitle: Text(
              '$detail${_needsReview.contains(id) ? '\nPerlu ditinjau sebelum dipilih' : ''}'
              '${_groupReview.contains(id) ? '\nTidak sesuai ${_studyGroup.label}; periksa sebelum memilih' : ''}',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    v! ? _selected.add(id) : _selected.remove(id);
                  }),
          ),
          if (extra != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: extra,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : edit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Periksa / koreksi'),
            ),
          ),
          if (_sources[id] != null)
            ExpansionTile(
              title: const Text('Teks pada dokumen'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(_sources[id]!),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Impor dokumen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Dokumenmu, jadi jadwalmu.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih PDF pembayaran, jadwal kuliah, atau kalender akademik. JPG/PNG juga bisa. Dokumen dibaca di HP, lalu kamu periksa sebelum diterapkan.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<StudyGroup>(
                key: ValueKey(_studyGroup),
                initialValue: _studyGroup,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kelompok kelas'),
                items: [
                  for (final g in StudyGroup.values)
                    DropdownMenuItem(value: g, child: Text(g.label)),
                ],
                onChanged: _busy
                    ? null
                    : (g) => setState(() {
                        _studyGroup = g!;
                        _groupChosen = true;
                        _checkGroup();
                      }),
              ),
              const SizedBox(height: 8),
              Text('${_studyGroup.description}. Jam kuliah mengikuti dokumen.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis dokumen'),
                items: const [
                  DropdownMenuItem(
                    value: DocumentKind.automatic,
                    child: Text('Kenali otomatis'),
                  ),
                  DropdownMenuItem(
                    value: DocumentKind.payments,
                    child: Text('Tagihan pembayaran'),
                  ),
                  DropdownMenuItem(
                    value: DocumentKind.schedule,
                    child: Text('Jadwal kuliah'),
                  ),
                  DropdownMenuItem(
                    value: DocumentKind.calendar,
                    child: Text('Kalender akademik'),
                  ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _kind = v!),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  _files.isEmpty ? 'Pilih dokumen' : 'Tambah dokumen',
                ),
              ),
              const Text('Maks. 20 MB dan 20 halaman per dokumen.'),
              if (_progress != null) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_progress!),
                TextButton(
                  onPressed: () => setState(() => _cancelled = true),
                  child: Text(
                    _cancelled ? 'Membatalkan...' : 'Batalkan pembacaan',
                  ),
                ),
              ],
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  _files.join('\n'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _semester,
                  enabled: !_busy,
                  maxLength: 100,
                  onChanged: (_) => setState(() => _targets.clear()),
                  decoration: const InputDecoration(
                    labelText: 'Semester tujuan',
                  ),
                ),
                for (final warning in _warnings.toSet())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $warning'),
                  ),
                if (_groupReview.isNotEmpty)
                  Text(
                    '${_groupReview.length} baris tidak sesuai kelompok kelas dan belum dipilih.',
                  ),
                const SizedBox(height: 16),
                Text(
                  'Tinjau hasil',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_subjects.length} mata kuliah · ${_payments.length} bayaran · ${_events.length} kegiatan',
                ),
                const Text(
                  'Centang yang akan diterapkan. Cocokkan mata kuliah agar tugas dan catatan tetap terhubung.',
                ),
                const SizedBox(height: 16),
                for (final s in _subjects)
                  _row(
                    s.id,
                    s.name,
                    '${s.scheduleDay} · ${s.scheduleTime}\n${s.room ?? ''} · ${s.lecturer ?? ''}',
                    () => _editSubject(s),
                    extra: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'target_${s.id}_${_target(s)?.id}_${_semester.text}',
                      ),
                      initialValue: _target(s)?.id ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Terapkan ke',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Mata kuliah baru'),
                        ),
                        for (final old in provider.subjects.where(
                          (o) =>
                              !o.isArchived &&
                              (o.semester == _semester.text.trim() ||
                                  o.semester.isEmpty),
                        ))
                          DropdownMenuItem(
                            value: old.id,
                            child: Text(
                              'Perbarui ${old.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _targets[s.id] = v!),
                    ),
                  ),
                for (final p in _payments)
                  _row(
                    p.id,
                    p.title,
                    '${p.amount == null ? 'Nominal belum diisi' : rupiah(p.amount!)}\n'
                    '${p.dueAt == null ? 'Jatuh tempo belum diketahui' : 'Jatuh tempo ${DateFormat('d MMM yyyy', 'id').format(p.dueAt!)}'}'
                    '${p.paidAt == null ? '' : '\nTanggal transaksi ${DateFormat('d MMM yyyy', 'id').format(p.paidAt!)}'}'
                    '${_oldPayment(p) == null ? '' : '\nMemperbarui tagihan yang sudah ada'}',
                    () => PaymentsSheet.edit(
                      context,
                      provider,
                      payment: p,
                      onSave: (value) async {
                        setState(() => _payments[_payments.indexOf(p)] = value);
                      },
                    ),
                    extra: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: p.isPaid,
                      title: const Text('Sudah dibayar'),
                      onChanged: _busy
                          ? null
                          : (v) => setState(
                              () => _payments[_payments.indexOf(p)] = p
                                  .copyWith(isPaid: v),
                            ),
                    ),
                  ),
                for (final e in _events)
                  _row(
                    e.id,
                    e.title,
                    '${DateFormat('d MMM yyyy', 'id').format(e.start)}${e.start == e.end ? '' : ' – ${DateFormat('d MMM yyyy', 'id').format(e.end)}'}'
                    '${e.kind == 'event' ? '' : '\nMentari libur selama periode ini'}',
                    () => _editEvent(e),
                  ),
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Jadwal/tanggal yang cocok akan diperbarui. Tugas dan catatan mata kuliah tetap tersimpan. Pengingat disusun ulang setelah penerapan.',
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _apply,
                  icon: const Icon(Icons.check),
                  label: Text(
                    _saving
                        ? 'Menyimpan...'
                        : 'Terapkan ${_selected.length} data terpilih',
                  ),
                ),
              ),
            ),
    ),
  );
}
