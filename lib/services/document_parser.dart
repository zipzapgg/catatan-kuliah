import 'dart:math' as math;
import '../models/academic_event.dart';
import '../models/academic_schedule.dart';
import '../models/document_draft.dart';
import '../models/subject.dart';
import '../models/tuition_payment.dart';

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = {
  'jan': 1,
  'januari': 1,
  'feb': 2,
  'februari': 2,
  'mar': 3,
  'maret': 3,
  'apr': 4,
  'april': 4,
  'mei': 5,
  'jun': 6,
  'juni': 6,
  'jul': 7,
  'juli': 7,
  'agt': 8,
  'ags': 8,
  'agu': 8,
  'agustus': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'okt': 10,
  'oktober': 10,
  'nov': 11,
  'november': 11,
  'des': 12,
  'desember': 12,
};

DateTime? _date(int year, int month, int day) {
  final result = DateTime(year, month, day);
  return year >= 2020 &&
          year <= 2100 &&
          result.year == year &&
          result.month == month &&
          result.day == day
      ? result
      : null;
}

/// Full Indonesian dates only; an absent year is never guessed.
({DateTime start, DateTime end, int length})? documentDate(String input) {
  final text = input.toLowerCase().replaceAll(RegExp('[–—−]'), '-');
  final iso = RegExp(r'^(20\d{2})-(\d{1,2})-(\d{1,2})(?!\d)').firstMatch(text);
  final numeric = RegExp(
    r'^(\d{1,2})[/.](\d{1,2})[/.](20\d{2})(?!\d)',
  ).firstMatch(text);
  if (iso != null || numeric != null) {
    final m = (iso ?? numeric)!;
    final date = iso != null
        ? _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!))
        : _date(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return date == null ? null : (start: date, end: date, length: m.end);
  }
  final months = _months.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final monthPattern = months.join('|');
  final m = RegExp(
    '^(\\d{1,2})\\s*(?:($monthPattern)\\.?\\s*(20\\d{2})?\\s*)?'
    '(?:-\\s*(\\d{1,2})\\s*)?($monthPattern)\\.?\\s*(20\\d{2})(?!\\d)',
  ).firstMatch(text);
  if (m == null) return null;
  final startYear = int.parse(m[3] ?? m[6]!);
  var startMonth = _months[m[2] ?? m[5]]!;
  final endMonth = _months[m[5]]!;
  final endYear = int.parse(m[6]!);
  final start = _date(startYear, startMonth, int.parse(m[1]!));
  final end = _date(endYear, endMonth, int.parse(m[4] ?? m[1]!));
  if (start == null ||
      end == null ||
      end.isBefore(start) ||
      end.difference(start).inDays > 366) {
    return null;
  }
  return (start: start, end: end, length: m.end);
}

int? documentAmount(String text) {
  final clean = text
      .replaceAll(RegExp(r'rp\.?|\s', caseSensitive: false), '')
      .trim();
  if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,00)?$').hasMatch(clean)) {
    return null;
  }
  final value = int.tryParse(clean.replaceAll('.', '').replaceFirst(',00', ''));
  return value != null && value <= 1000000000000 ? value : null;
}

List<List<DocumentWord>> documentLines(List<DocumentWord> words) {
  final sorted = List<DocumentWord>.of(words)
    ..sort((a, b) => a.y.compareTo(b.y));
  final rows = <List<DocumentWord>>[];
  for (final word in sorted) {
    if (word.text.trim().isEmpty) continue;
    if (rows.isEmpty ||
        (rows.last.first.y - word.y).abs() >
            math.max(2, math.min(rows.last.first.height, word.height) * .5)) {
      rows.add([word]);
    } else {
      rows.last.add(word);
    }
  }
  for (final row in rows) {
    row.sort((a, b) => a.left.compareTo(b.left));
  }
  return rows;
}

String _text(Iterable<DocumentWord> words) => documentLines(words.toList())
    .map((line) => line.map((w) => w.text).join(' '))
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

({double left, double right})? _column(
  List<DocumentWord> header,
  String label,
) {
  final parts = label.split(' ');
  for (var i = 0; i <= header.length - parts.length; i++) {
    if (List.generate(
          parts.length,
          (n) => header[i + n].text.toUpperCase(),
        ).join(' ') !=
        label) {
      continue;
    }
    final last = i + parts.length - 1;
    return (
      left: i == 0 ? 0 : (header[i - 1].right + header[i].left) / 2,
      right: last == header.length - 1
          ? double.infinity
          : (header[last].right + header[last + 1].left) / 2,
    );
  }
  return null;
}

String _cell(List<DocumentWord> row, ({double left, double right})? column) =>
    column == null
    ? ''
    : _text(row.where((w) => w.x >= column.left && w.x < column.right));

String _key(String kind, String semester, String value) =>
    '${kind}_${importName(semester)}_${importName(value)}';

class DocumentParser {
  DocumentDraft parse(
    String fileName,
    List<DocumentPage> pages, {
    DocumentKind kind = DocumentKind.automatic,
    required String fallbackSemester,
  }) {
    final fullText = pages.map((p) => _text(p.words)).join('\n');
    final years = RegExp(r'(20\d{2})\s*/\s*(20\d{2})').firstMatch(fullText);
    final term = RegExp(
      r'\b(gasal|ganjil|genap)\b',
      caseSensitive: false,
    ).firstMatch(fullText);
    final semester = years == null || term == null
        ? fallbackSemester
        : '${fullText.toUpperCase().contains('PAMULANG') || fallbackSemester.startsWith('UNPAM') ? 'UNPAM ' : ''}'
              '${term[1]!.toLowerCase() == 'genap' ? 'Genap' : 'Gasal'} ${years[1]}/${years[2]}';
    final warnings = <String>[];
    if (years == null || term == null) {
      warnings.add('Semester tidak terbaca lengkap. Periksa semester tujuan.');
    }
    if (pages.any((p) => p.usedOcr)) {
      warnings.add(
        'Dokumen dibaca dengan OCR. Periksa kembali nama, angka, dan tanggal.',
      );
    }
    if (kind == DocumentKind.automatic) {
      final lines = pages.expand((p) => documentLines(p.words));
      kind =
          lines.any(
            (l) =>
                _column(l, 'STATUS BAYAR') != null &&
                _column(l, 'JML BAYAR') != null,
          )
          ? DocumentKind.payments
          : lines.any(
              (l) =>
                  _column(l, 'NAMA MATA KULIAH') != null &&
                  _column(l, 'HARI') != null &&
                  _column(l, 'WAKTU') != null,
            )
          ? DocumentKind.schedule
          : DocumentKind.calendar;
    }
    final subjects = <Subject>[];
    final payments = <TuitionPayment>[];
    final events = <AcademicEvent>[];
    final sources = <String, String>{};
    final review = <String>{};
    for (final page in pages) {
      switch (kind) {
        case DocumentKind.schedule:
          _schedule(page, semester, subjects, sources, warnings);
        case DocumentKind.payments:
          _payments(page, semester, payments, sources, warnings);
        case DocumentKind.calendar:
          _calendar(
            page,
            semester,
            events,
            payments,
            sources,
            review,
            warnings,
          );
        case DocumentKind.automatic:
          break;
      }
    }
    if (payments.any((p) => !p.isPaid && p.dueAt == null)) {
      warnings.add(
        'Tagihan belum lunas tanpa jatuh tempo disimpan tanpa pengingat. TGL BAYAR hanya mencatat tanggal transaksi.',
      );
    }
    if (kind == DocumentKind.calendar) {
      for (final exam in ['UTS', 'UAS']) {
        if (!events.any((e) => e.kind == exam)) {
          warnings.add(
            'Periode $exam belum terbaca lengkap. Jadwal $exam yang sudah ada dipertahankan; atur tanggalnya dari Kalender jika perlu.',
          );
        }
      }
    }
    if (review.isNotEmpty) {
      warnings.add(
        '${review.length} kegiatan perlu ditinjau karena tahun atau jenis kegiatannya berbeda.',
      );
    }
    if (subjects.isEmpty && payments.isEmpty && events.isEmpty) {
      warnings.add(
        'Belum ada data yang dapat dikenali. Coba jenis dokumen lain atau PDF asli yang lebih jelas.',
      );
    }
    return DocumentDraft(
      fileName: fileName,
      semester: semester,
      studyGroup: kind == DocumentKind.schedule
          ? StudyGroup.values
                .where(
                  (g) => RegExp(
                    '\\breguler\\s+${g.name}\\b',
                    caseSensitive: false,
                  ).hasMatch(fullText),
                )
                .firstOrNull
          : null,
      subjects: subjects,
      payments: payments,
      events: events,
      sources: sources,
      warnings: warnings,
      needsReview: review,
    );
  }

  void _schedule(
    DocumentPage page,
    String semester,
    List<Subject> output,
    Map<String, String> sources,
    List<String> warnings,
  ) {
    final lines = documentLines(page.words);
    final header = lines
        .where(
          (l) =>
              _column(l, 'NAMA MATA KULIAH') != null &&
              _column(l, 'HARI') != null &&
              _column(l, 'WAKTU') != null,
        )
        .firstOrNull;
    if (header == null) {
      warnings.add('Halaman ${page.number}: kolom jadwal belum dikenali.');
      return;
    }
    final dayColumn = _column(header, 'HARI')!;
    final anchors =
        page.words
            .where(
              (w) =>
                  w.y > header.first.y &&
                  w.x >= dayColumn.left &&
                  w.x < dayColumn.right &&
                  _days.any((d) => d.toLowerCase() == w.text.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.y.compareTo(b.y));
    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final top = i == 0
          ? (header.first.y + a.y) / 2
          : (anchors[i - 1].y + a.y) / 2;
      final bottom = i == anchors.length - 1
          ? a.y + a.height * 2
          : (a.y + anchors[i + 1].y) / 2;
      final row = page.words.where((w) => w.y > top && w.y < bottom).toList();
      String cell(String name) => _cell(row, _column(header, name));
      final name = cell('NAMA MATA KULIAH');
      final time = cell(
        'WAKTU',
      ).replaceAll('.', ':').replaceAll(RegExp('[–—]'), '-');
      final m = RegExp(
        r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$',
      ).firstMatch(time);
      if (name.isEmpty ||
          name.length > 200 ||
          m == null ||
          int.parse(m[1]!) > 23 ||
          int.parse(m[3]!) > 23 ||
          int.parse(m[2]!) > 59 ||
          int.parse(m[4]!) > 59 ||
          int.parse(m[3]!) * 60 + int.parse(m[4]!) <=
              int.parse(m[1]!) * 60 + int.parse(m[2]!)) {
        warnings.add(
          'Halaman ${page.number}: satu baris jadwal tidak lengkap; belum dimasukkan.',
        );
        continue;
      }
      final id = _key(
        'pdf_subject',
        semester,
        cell('KODE MK').isEmpty ? name : cell('KODE MK'),
      );
      output.add(
        Subject(
          id: id,
          name: name,
          colorValue: 0xFF30343B,
          semester: semester,
          scheduleDay: _days.firstWhere(
            (d) => d.toLowerCase() == a.text.toLowerCase(),
          ),
          scheduleTime:
              '${m[1]!.padLeft(2, '0')}:${m[2]} - ${m[3]!.padLeft(2, '0')}:${m[4]}',
          lecturer: cell('DOSEN').isEmpty ? null : cell('DOSEN'),
          room: cell('RUANG').isEmpty ? null : cell('RUANG'),
        ),
      );
      sources[id] = 'Halaman ${page.number}: ${_text(row)}';
    }
  }

  void _payments(
    DocumentPage page,
    String semester,
    List<TuitionPayment> output,
    Map<String, String> sources,
    List<String> warnings,
  ) {
    final header = documentLines(page.words)
        .where(
          (l) =>
              _column(l, 'STATUS BAYAR') != null &&
              _column(l, 'JML BAYAR') != null,
        )
        .firstOrNull;
    if (header == null) {
      warnings.add('Halaman ${page.number}: kolom tagihan belum dikenali.');
      return;
    }
    final number = _column(header, 'NOMOR TAGIHAN');
    if (number == null) {
      warnings.add(
        'Nomor tagihan tidak ditemukan; belum dapat mencocokkan tagihan.',
      );
      return;
    }
    final anchors =
        page.words
            .where(
              (w) =>
                  w.y > header.first.y &&
                  w.x >= number.left &&
                  w.x < number.right &&
                  RegExp(r'^\d{8,24}$').hasMatch(w.text),
            )
            .toList()
          ..sort((a, b) => a.y.compareTo(b.y));
    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final top = i == 0
          ? (header.first.y + a.y) / 2
          : (anchors[i - 1].y + a.y) / 2;
      final bottom = i == anchors.length - 1
          ? a.y + a.height * 2
          : (a.y + anchors[i + 1].y) / 2;
      final row = page.words.where((w) => w.y > top && w.y < bottom).toList();
      String cell(String name) => _cell(row, _column(header, name));
      final title = cell('PEMBAYARAN');
      final amount = documentAmount(cell('JML BAYAR'));
      final status = cell('STATUS BAYAR').toUpperCase().trim();
      if (title.isEmpty ||
          amount == null ||
          !['LUNAS', 'BELUM LUNAS'].contains(status)) {
        warnings.add(
          'Halaman ${page.number}: satu tagihan memiliki nominal/status yang belum terbaca; belum dimasukkan.',
        );
        continue;
      }
      final paid = status == 'LUNAS';
      final due = documentDate(cell('JATUH TEMPO'))?.start;
      final id = 'bill_${a.text}';
      output.add(
        TuitionPayment(
          id: id,
          title: title,
          amount: amount,
          semester: semester,
          isPaid: paid,
          paidAt: paid ? documentDate(cell('TGL BAYAR'))?.start : null,
          dueAt: due == null ? null : DateTime(due.year, due.month, due.day, 9),
        ),
      );
      sources[id] = 'Halaman ${page.number}: ${_text(row)}';
    }
  }

  void _calendar(
    DocumentPage page,
    String semester,
    List<AcademicEvent> events,
    List<TuitionPayment> payments,
    Map<String, String> sources,
    Set<String> review,
    List<String> warnings,
  ) {
    final anchors = <DocumentWord>[];
    final consumedWords = <DocumentWord>{};
    final candidates = List<DocumentWord>.of(page.words)
      ..sort(
        (a, b) => a.left == b.left
            ? a.top.compareTo(b.top)
            : a.left.compareTo(b.left),
      );
    final dates =
        <
          ({
            DocumentWord first,
            double right,
            DateTime start,
            DateTime end,
            String label,
            bool uncertain,
          })
        >[];
    var unreadableDates = 0;
    for (final first in candidates) {
      if (consumedWords.contains(first) ||
          !RegExp(r'^[\dIlJ|]').hasMatch(first.text)) {
        continue;
      }
      // Date rows are grouped locally so large calendar-grid numbers cannot split their year.
      final band =
          page.words
              .where(
                (w) =>
                    w.left >= first.left &&
                    (w.y - first.y).abs() <=
                        math.max(2, math.min(first.height, w.height) * .7),
              )
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));
      final line = <DocumentWord>[];
      for (final w in band) {
        if (line.isNotEmpty &&
            w.left - line.last.right > math.max(first.height * 3, 20)) {
          break;
        }
        line.add(w);
      }
      final value = line.map((w) => w.text).join(' ');
      // OCR can read a leading 1 as I/l/J; corrected dates always require review.
      final dateText = page.usedOcr
          ? value.replaceFirst(
              RegExp(r'^[IlJ|](?=\d(?:[-–—]\d{1,2})?(?:\s|$))'),
              '1',
            )
          : value;
      final uncertain = value != dateText;
      final separate = RegExp(r'^(\d{1,2})\s*[&,]\s*').firstMatch(dateText);
      final date = documentDate(
        separate == null ? dateText : dateText.substring(separate.end),
      );
      if (date == null) {
        if (RegExp(
              '^\\d{1,4}(?:\\s*[-–—&,]\\s*\\d{1,2})?\\s*(?:${_months.keys.join('|')})\\b',
              caseSensitive: false,
            ).hasMatch(dateText) ||
            RegExp(r'^\d{1,2}\s+[A-Za-z]{3,14}\s+20\d{2}').hasMatch(dateText)) {
          anchors.add(first);
          consumedWords.addAll(line);
          unreadableDates++;
        }
        continue;
      }
      anchors.add(first);
      final length = date.length + (separate?.end ?? 0);
      var consumed = 0;
      var last = 0;
      for (; last < line.length; last++) {
        consumed += line[last].text.length;
        if (consumed >= length) break;
        consumed++;
      }
      if (last >= line.length) continue;
      consumedWords.addAll(line.take(last + 1));
      dates.add((
        first: first,
        right: line[last].right,
        start: date.start,
        end: date.end,
        label: value.substring(0, length),
        uncertain: uncertain,
      ));
      if (separate != null) {
        final extra = _date(
          date.start.year,
          date.start.month,
          int.parse(separate[1]!),
        );
        if (extra != null && extra != date.start) {
          dates.add((
            first: first,
            right: line[last].right,
            start: extra,
            end: extra,
            label: value.substring(0, length),
            uncertain: uncertain,
          ));
        }
      }
    }
    if (unreadableDates > 0) {
      warnings.add(
        'Halaman ${page.number}: $unreadableDates tanggal belum terbaca lengkap; kegiatannya belum dimasukkan.',
      );
    }
    if (dates.any((d) => d.uncertain)) {
      warnings.add(
        'Ada angka OCR yang ambigu. Tanggal hasil koreksi belum dipilih otomatis; cocokkan dengan dokumen sebelum memilihnya.',
      );
    }
    for (final date in dates) {
      final column =
          anchors
              .where(
                (d) => (d.left - date.first.left).abs() < page.width * .035,
              )
              .toList()
            ..sort((a, b) => a.y.compareTo(b.y));
      final next = column
          .where((d) => d.y > date.first.y + date.first.height * .6)
          .firstOrNull;
      final nextColumn = anchors
          .where(
            (d) =>
                d.left > date.right + page.width * .12 &&
                anchors
                        .where(
                          (a) => (a.left - d.left).abs() < page.width * .035,
                        )
                        .length >=
                    2,
          )
          .map((d) => d.left)
          .fold(page.width, math.min);
      final bottom = math.min(
        next?.top ?? page.height,
        date.first.bottom + date.first.height * 4,
      );
      final words = page.words
          .where(
            (w) =>
                w.x > date.right &&
                w.x < nextColumn &&
                w.y >= date.first.y - date.first.height * .6 &&
                w.y < bottom,
          )
          .toList();
      final title = _text(
        words,
      ).replaceFirst(RegExp(r'^\s*[:;|]\s*'), '').trim();
      if (title.length < 4 || title.length > 300) continue;
      final normalized = title.toLowerCase();
      final irrelevant = RegExp(
        r'pmb|spmb|calon|mahasiswa baru|penelitian|pengabdian|dosen|input.*nilai|validasi|pk(k|m)|rapat|sinkronisasi|[il]jazah|sis(k|c)emu|feeder|bk(d|d)|pak\b|generate|asc system|edit jadwal|pengisian jadwal|penyusunan jadwal|matrikulasi',
        caseSensitive: false,
      ).hasMatch(title);
      final year = RegExp(r'(20\d{2})/(20\d{2})').firstMatch(semester);
      final outside =
          year != null &&
          (date.start.year < int.parse(year[1]!) ||
              date.end.year > int.parse(year[2]!));
      final payment = RegExp(
        r'pelunasan|batas.*pembayaran',
        caseSensitive: false,
      ).hasMatch(title);
      var kind = 'event';
      if (!RegExp(
        r'susulan|revisi|pendaftaran|nilai',
        caseSensitive: false,
      ).hasMatch(title)) {
        if (RegExp(
          r'pekan\s*uts|ujian tengah semester',
          caseSensitive: false,
        ).hasMatch(title)) {
          kind = 'UTS';
        }
        if (RegExp(
          r'pekan\s*uas|ujian akhir semester',
          caseSensitive: false,
        ).hasMatch(title)) {
          kind = 'UAS';
        }
      }
      final id = _key(
        payment ? 'calendar_payment' : 'calendar_event',
        semester,
        kind == 'event' ? '$title ${dateKey(date.start)}' : kind,
      );
      if (sources.containsKey(id)) continue;
      if (payment) {
        payments.add(
          TuitionPayment(
            id: id,
            title: title.length > 200 ? title.substring(0, 200) : title,
            semester: semester,
            dueAt: DateTime(date.end.year, date.end.month, date.end.day, 9),
          ),
        );
        sources[payments.last.id] =
            'Halaman ${page.number}: ${date.label} · $title';
        if (outside || date.uncertain) review.add(payments.last.id);
      } else {
        events.add(
          AcademicEvent(
            id: id,
            title: title,
            semester: semester,
            start: date.start,
            end: date.end,
            kind: kind,
          ),
        );
        sources[events.last.id] =
            'Halaman ${page.number}: ${date.label} · $title';
        if (irrelevant ||
            outside ||
            date.uncertain ||
            normalized.contains('&') && date.start == date.end) {
          review.add(events.last.id);
        }
      }
    }
  }
}
