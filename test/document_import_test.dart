import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_tugas_kuliah/models/academic_event.dart';
import 'package:catatan_tugas_kuliah/models/document_draft.dart';
import 'package:catatan_tugas_kuliah/models/tuition_payment.dart';
import 'package:catatan_tugas_kuliah/models/unpam_calendar.dart';
import 'package:catatan_tugas_kuliah/providers/app_provider.dart';
import 'package:catatan_tugas_kuliah/services/document_parser.dart';
import 'package:catatan_tugas_kuliah/services/reminder_plan.dart';
import 'package:catatan_tugas_kuliah/services/storage_service.dart';
import 'package:catatan_tugas_kuliah/screens/document_import_screen.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'regression_test.dart'
    show sample, loadProvider, showApp, RejectingStore;

const semester = 'UNPAM Gasal 2026/2027';
List<DocumentWord> words(String text, double x, double y) {
  final output = <DocumentWord>[];
  for (final word in text.split(' ')) {
    output.add(DocumentWord(word, x, y, x + word.length * 5, y + 10));
    x += word.length * 5 + 5;
  }
  return output;
}

DocumentPage table(List<String> headers, List<List<String>> rows) =>
    DocumentPage(1, headers.length * 240, 800, [
      ...words('UNIVERSITAS PAMULANG SEMESTER GANJIL 2026/2027', 20, 10),
      for (var col = 0; col < headers.length; col++)
        ...words(headers[col], col * 240 + 20, 60),
      for (var row = 0; row < rows.length; row++)
        for (var col = 0; col < headers.length; col++)
          for (var line = 0; line < rows[row][col].split('\n').length; line++)
            ...words(
              rows[row][col].split('\n')[line],
              col * 240 + 20,
              120 + row * 80 + line * 12,
            ),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'class rules preserve explicit times and flag conflicting days or calendar groups',
    () {
      final page = table(
        ['NAMA MATA KULIAH', 'HARI', 'WAKTU'],
        [
          ['KELAS SATU', 'Kamis', '07.10 - 08.50'],
          ['KELAS DUA', 'Sabtu', '18.30 - 20.10'],
          ['KELAS TIGA', 'Jumat', '14.40 - 16.20'],
        ],
      );
      page.words.addAll(words('REGULER A', 20, 30));
      final draft = DocumentParser().parse('jadwal.pdf', [
        page,
      ], fallbackSemester: semester);
      expect(draft.studyGroup, StudyGroup.a);
      expect(draft.reviewForGroup(StudyGroup.a), {draft.subjects[0].id});
      expect(draft.reviewForGroup(StudyGroup.b), {draft.subjects[1].id});
      expect(draft.reviewForGroup(StudyGroup.ck), {
        draft.subjects[1].id,
        draft.subjects[2].id,
      });
      expect(draft.reviewForGroup(StudyGroup.cs), {
        draft.subjects[0].id,
        draft.subjects[2].id,
      });
      expect(draft.subjects[2].scheduleTime, '14:40 - 16:20');
      for (final group in StudyGroup.values) {
        expect(group.includesTitle('Pekan UTS'), true);
        expect(
          group.includesTitle('Pelunasan Reg. A & B'),
          [StudyGroup.a, StudyGroup.b].contains(group),
        );
        expect(
          group.includesTitle('Awal Reg. CK & CS Kelompok MK 2'),
          [StudyGroup.ck, StudyGroup.cs].contains(group),
        );
      }
    },
  );
  test(
    'strict Indonesian date and rupiah parsing never invents invalid dates or amounts',
    () {
      expect(
        documentDate('19 – 24 Oktober 2026 : Pekan UTS')?.end,
        DateTime(2026, 10, 24),
      );
      final cross = documentDate('14 Desember 2026 – 2 Jan 2027');
      expect(cross?.start, DateTime(2026, 12, 14));
      expect(cross?.end, DateTime(2027, 1, 2));
      expect(documentDate('31 Februari 2026'), null);
      expect(documentDate('13 Oktober'), null);
      expect(
        documentDate('2026-10-13 12:43:19')?.start,
        DateTime(2026, 10, 13),
      );
      expect(documentAmount('Rp 1.250.000,00'), 1250000);
      expect(documentAmount('250000'), 250000);
      for (final invalid in [
        '1.25',
        'Rp -200000',
        '200,50',
        '20O000',
        '1000000000001',
      ]) {
        expect(documentAmount(invalid), null, reason: invalid);
      }
    },
  );

  test(
    'schedule columns can move and multiline names retain the correct day and lecturer',
    () {
      final page = table(
        ['HARI', 'NAMA MATA KULIAH', 'DOSEN', 'WAKTU', 'RUANG'],
        [
          [
            'Senin',
            'DASAR\nPEMROGRAMAN',
            'DOSEN SATU',
            '07.10 - 08.50',
            'R.101',
          ],
          ['Rabu', 'BASIS DATA', 'DOSEN DUA', '13.00 - 14.40', 'R.202'],
        ],
      );
      final result = DocumentParser().parse('jadwal.pdf', [
        page,
      ], fallbackSemester: semester);
      expect(result.subjects, hasLength(2));
      expect(result.subjects.first.name, 'DASAR PEMROGRAMAN');
      expect(result.subjects.first.scheduleTime, '07:10 - 08:50');
      expect(result.subjects.last.lecturer, 'DOSEN DUA');
      expect(result.subjects.last.scheduleDay, 'Rabu');
    },
  );

  test(
    'billing distinguishes paid transactions from future deadlines and pending bills',
    () {
      final page = table(
        [
          'NOMOR TAGIHAN',
          'PEMBAYARAN',
          'JML BAYAR',
          'STATUS BAYAR',
          'TGL BAYAR',
        ],
        [
          ['900000000001', 'ANGSURAN KE-1', '100000', 'LUNAS', '2026-08-01'],
          ['900000000002', 'ANGSURAN KE-2', '200000', 'BELUM LUNAS', ''],
        ],
      );
      final result = DocumentParser().parse('tagihan.pdf', [
        page,
      ], fallbackSemester: semester);
      expect(result.payments, hasLength(2));
      expect(result.payments.first.isPaid, true);
      expect(result.payments.first.paidAt, DateTime(2026, 8, 1));
      expect(result.payments.last.isPaid, false);
      expect(result.payments.every((p) => p.dueAt == null), true);
      expect(
        planReminders([], DateTime(2026, 7), payments: result.payments),
        isEmpty,
      );
      final again = DocumentParser().parse('renamed.pdf', [
        page,
      ], fallbackSemester: semester);
      expect(again.payments.map((p) => p.id), result.payments.map((p) => p.id));
    },
  );

  test(
    'calendar reads both columns, separate days and flags other years or groups',
    () {
      final page = DocumentPage(1, 1600, 800, [
        ...words('UNPAM SEMESTER GASAL 2026/2027', 20, 10),
        ...words('Mata kuliah dapat berubah sewaktu-waktu', 20, 35),
        ...words('19 - 24 Oktober 2026', 20, 100),
        ...words(': Pekan UTS', 300, 100),
        ...words('8 Desember 2026', 800, 100),
        ...words(': Batas Pelunasan Reg. A & B', 1050, 100),
        ...words('29 & 31 Oktober 2026', 20, 150),
        ...words(': UTS susulan', 300, 150),
        ...words('10 Desember 2026', 800, 150),
        ...words(': Batas Pelunasan Reg. CK & CS', 1050, 150),
        ...words('14 - 19 Desember 2026', 20, 200),
        ...words(': Pekan UAS', 300, 200),
        ...words('25 Desember 2025', 800, 200),
        ...words(': Hari Natal', 1050, 200),
      ], usedOcr: true);
      final result = DocumentParser().parse('kalender.jpg', [
        page,
      ], fallbackSemester: semester);
      expect(
        result.events.where((e) => e.kind == 'UTS').single.end,
        DateTime(2026, 10, 24),
      );
      expect(
        result.events.where((e) => e.kind == 'UAS').single.start,
        DateTime(2026, 12, 14),
      );
      expect(
        result.events
            .where((e) => e.title == 'UTS susulan')
            .map((e) => e.start)
            .toSet(),
        {DateTime(2026, 10, 29), DateTime(2026, 10, 31)},
      );
      expect(result.payments, hasLength(2));
      expect(
        result.reviewForGroup(StudyGroup.a),
        contains(result.payments.last.id),
      );
      expect(
        result.needsReview,
        contains(result.events.where((e) => e.title == 'Hari Natal').single.id),
      );
    },
  );

  test(
    'atomic import preserves coursework, deduplicates bills, persists calendar without courses',
    () async {
      final original = sample().copyWith(semester: semester);
      final provider = await loadProvider([original]);
      addTearDown(provider.dispose);
      final payment = TuitionPayment(
        id: 'bill',
        title: 'Angsuran',
        semester: semester,
        amount: 200000,
      );
      final event = AcademicEvent(
        id: 'uts',
        title: 'Pekan UTS',
        semester: semester,
        kind: 'UTS',
        start: DateTime(2026, 10, 19),
        end: DateTime(2026, 10, 24),
      );
      final incoming = original.copyWith(
        name: 'Nama resmi',
        scheduleDay: 'Rabu',
        scheduleTime: '07:10 - 08:50',
        tasks: [],
      );
      for (var i = 0; i < 2; i++) {
        await provider.applyDocument(
          subjects: [incoming],
          payments: [payment],
          events: [event],
        );
      }
      expect(
        provider.subjects.single.tasks.map((t) => t.toJson()),
        original.tasks.map((t) => t.toJson()),
      );
      expect(
        provider.subjects.single.notes.map((n) => n.toJson()),
        original.notes.map((n) => n.toJson()),
      );
      expect(provider.subjects.single.scheduleDay, 'Rabu');
      expect(provider.payments, hasLength(1));
      expect(provider.events, hasLength(1));
      expect(provider.subjects.single.examBreaks.single.start, event.start);
      await provider.deleteSubject(original.id);
      final reopened = AppProvider();
      await reopened.waitUntilReady();
      addTearDown(reopened.dispose);
      expect(reopened.events.single.toJson(), event.toJson());
      await reopened.addSubject('Kelas baru', 0xFF303030, semester: semester);
      expect(
        reopened.subjects.single.examBreaks.any(
          (b) => b.name == 'UTS' && b.start == event.start,
        ),
        true,
      );
      final backup = reopened.exportData();
      expect(StorageService().importEventsFromJson(backup).single.id, 'uts');
      final broken = jsonDecode(backup) as Map<String, dynamic>;
      broken['events'][0]['end'] = '2026-01-01';
      expect(StorageService().importFromJson(jsonEncode(broken)), null);
    },
  );

  test(
    'OCR date rows tolerate mixed font baselines and ambiguous digits require review',
    () {
      final draft = DocumentParser().parse('scan.jpg', [
        DocumentPage(1, 1600, 800, [
          ...words('UNPAM SEMESTER GASAL 2026/2027', 20, 10),
          const DocumentWord('16', 2, 82, 15, 111),
          const DocumentWord('19-24', 20, 100, 55, 113),
          const DocumentWord('Oktober', 65, 100, 106, 112),
          const DocumentWord('2026', 112, 99, 140, 112),
          ...words(': Pekan UTS', 250, 106),
          ...words('J4-19 Desember 2026', 20, 160),
          ...words(': Pekan UAS', 250, 163),
          ...words('14 Desermber 2026', 20, 200),
          ...words(': Kegiatan berikutnya', 250, 200),
        ], usedOcr: true),
      ], fallbackSemester: semester);
      expect(draft.events, hasLength(2));
      final uts = draft.events.singleWhere((e) => e.kind == 'UTS');
      final uas = draft.events.singleWhere((e) => e.kind == 'UAS');
      expect(uts.end, DateTime(2026, 10, 24));
      expect(uas.start, DateTime(2026, 12, 14));
      expect(uas.title, 'Pekan UAS');
      expect(draft.needsReview, contains(uas.id));
      expect(draft.sources[uas.id], contains('J4-19'));
      expect(
        draft.warnings.any((w) => w.contains('belum terbaca lengkap')),
        true,
      );
    },
  );

  testWidgets(
    'an older bill cannot silently revert paid status or discard a known deadline',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      final existing = TuitionPayment(
        id: 'bill-paid',
        title: 'Angsuran',
        semester: semester,
        amount: 200000,
        isPaid: true,
        dueAt: DateTime(2026, 12, 8, 9),
      );
      await provider.savePayment(existing);
      await showApp(
        tester,
        provider,
        home: DocumentImportScreen(
          provider: provider,
          initialDraft: DocumentDraft(
            fileName: 'tagihan-lama.pdf',
            semester: semester,
            payments: [existing.copyWith(isPaid: false, dueAt: null)],
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Angsuran'),
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      final tile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Angsuran'),
      );
      expect(tile.value, false);
      expect(find.text('Terapkan 1 data terpilih'), findsNothing);
      expect(find.textContaining('Jatuh tempo 8 Des 2026'), findsOneWidget);
      expect(provider.payments.single.isPaid, true);
      expect(provider.payments.single.dueAt, existing.dueAt);
    },
  );

  testWidgets(
    'calendar import matches the existing A/B reminder and preserves its amount and paid status',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      final existing = UnpamCalendar.payments.first.copyWith(
        amount: 450000,
        isPaid: true,
      );
      await provider.savePayment(existing);
      const title = 'Batas Akhir Pelunasan Reg. A & B Angsuran Ke-3 & UTS';
      await showApp(
        tester,
        provider,
        home: DocumentImportScreen(
          provider: provider,
          initialDraft: DocumentDraft(
            fileName: 'kalender.jpg',
            semester: semester,
            payments: [
              TuitionPayment(
                id: 'calendar_payment_new',
                title: title,
                semester: semester,
                dueAt: DateTime(2026, 10, 14, 9),
              ),
            ],
          ),
        ),
      );
      final scroll = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: scroll,
      );
      expect(
        find.textContaining('Memperbarui tagihan yang sudah ada'),
        findsOneWidget,
      );
      expect(find.textContaining('450.000'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sudah dibayar'),
        100,
        scrollable: scroll,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Sudah dibayar'),
            )
            .value,
        true,
      );
      expect(provider.payments, hasLength(1));
      expect(provider.payments.single.toJson(), existing.toJson());
      expect(tester.takeException(), null);
    },
  );

  test('failed import never publishes partial dates or money', () async {
    final original = sample();
    final provider = await loadProvider([original]);
    addTearDown(provider.dispose);
    final before = provider.exportData();
    final oldStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = RejectingStore({});
    addTearDown(() => SharedPreferencesStorePlatform.instance = oldStore);
    await expectLater(
      provider.applyDocument(
        subjects: [original.copyWith(name: 'Changed')],
        payments: [
          const TuitionPayment(
            id: 'bill',
            title: 'Angsuran',
            semester: semester,
          ),
        ],
        events: [],
      ),
      throwsA(isA<StorageException>()),
    );
    expect(provider.exportData(), before);
  });

  testWidgets(
    'review is editable, large-text safe and applies only selected rows',
    (tester) async {
      final original = sample();
      final provider = await loadProvider([original]);
      addTearDown(provider.dispose);
      final draft = DocumentDraft(
        fileName: 'uji.pdf',
        semester: semester,
        payments: [
          const TuitionPayment(
            id: 'bill-a',
            title: 'Angsuran pertama',
            semester: semester,
            amount: 200000,
          ),
          const TuitionPayment(
            id: 'bill-b',
            title: 'Angsuran kedua',
            semester: semester,
            amount: 300000,
          ),
        ],
      );
      await showApp(
        tester,
        provider,
        scale: 2,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DocumentImportScreen(
                    provider: provider,
                    initialDraft: draft,
                  ),
                ),
              ),
              child: const Text('Buka impor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka impor'));
      await tester.pumpAndSettle();
      expect(provider.payments, isEmpty);
      final scroll = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.text('Angsuran pertama'),
        100,
        scrollable: scroll,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Angsuran pertama')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Angsuran pertama'));
      await tester.pumpAndSettle();
      final apply = find.text('Terapkan 1 data terpilih');
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(provider.payments.single.id, 'bill-b');
      expect(provider.subjects.single.tasks.length, original.tasks.length);
      expect(tester.takeException(), null);
    },
  );
}
