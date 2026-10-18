import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_tugas_kuliah/models/subject.dart';
import 'package:catatan_tugas_kuliah/models/tuition_payment.dart';
import 'package:catatan_tugas_kuliah/models/unpam_calendar.dart';
import 'package:catatan_tugas_kuliah/models/academic_schedule.dart';
import 'package:catatan_tugas_kuliah/providers/app_provider.dart';
import 'package:catatan_tugas_kuliah/services/storage_service.dart';
import 'package:catatan_tugas_kuliah/services/reminder_plan.dart';
import 'package:catatan_tugas_kuliah/screens/dashboard_screen.dart';
import 'package:catatan_tugas_kuliah/screens/widgets/payments_sheet.dart';
// Reproduce platform storage failure using the same store as the regression suite.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'regression_test.dart'
    show sample, loadProvider, showApp, snapshot, loadFonts, RejectingStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);

  test('UNPAM dates follow supplied calendar and A/B payment deadlines', () {
    final exams = UnpamCalendar.examBreaks;
    expect(exams[0].start, DateTime(2026, 10, 19));
    expect(exams[0].end, DateTime(2026, 10, 24));
    expect(exams[1].start, DateTime(2026, 12, 14));
    expect(exams[1].end, DateTime(2026, 12, 19));
    expect(UnpamCalendar.mentariEnd, DateTime(2026, 12, 13));
    expect(UnpamCalendar.payments.map((p) => dateKey(p.dueAt!)), [
      '2026-10-13',
      '2026-12-08',
    ]);
    expect(
      UnpamCalendar.payments.every((p) => p.amount == null && !p.isPaid),
      true,
    );
    expect(
      UnpamCalendar.eventsOn(
        DateTime(2026, 10, 30),
      ).contains('Pelaksanaan UTS susulan'),
      false,
    );
    expect(
      UnpamCalendar.eventsOn(
        DateTime(2026, 10, 31),
      ).contains('Pelaksanaan UTS susulan'),
      true,
    );
    expect(
      UnpamCalendar.eventsOn(DateTime(2027, 1, 26)),
      contains('Herregistrasi mahasiswa lama'),
    );
    expect(
      UnpamCalendar.eventsOn(DateTime(2027, 1, 27)),
      isNot(contains('Herregistrasi mahasiswa lama')),
    );
  });

  test(
    'applying calendar preserves coursework and other semesters without duplicating or resetting payments',
    () async {
      final original = sample();
      final other = Subject(
        id: 'other',
        name: 'Semester sebelumnya',
        colorValue: 0xFF123456,
        semester: '2025',
      );
      final archived = Subject(
        id: 'archive',
        name: 'Arsip',
        colorValue: 0xFF123456,
        isArchived: true,
      );
      final provider = await loadProvider([original, other, archived]);
      addTearDown(provider.dispose);
      await provider.applyUnpamCalendar();
      expect(provider.subjects[0].semester, UnpamCalendar.semester);
      expect(
        provider.subjects[0].tasks.map((t) => t.toJson()),
        original.tasks.map((t) => t.toJson()),
      );
      expect(
        provider.subjects[0].notes.map((n) => n.toJson()),
        original.notes.map((n) => n.toJson()),
      );
      expect(provider.subjects[1].toJson(), other.toJson());
      expect(provider.subjects[2].toJson(), archived.toJson());
      final changed = provider.payments.first.copyWith(
        amount: 250000,
        isPaid: true,
      );
      await provider.savePayment(changed);
      await provider.applyUnpamCalendar();
      expect(provider.payments, hasLength(2));
      expect(provider.payments.first.toJson(), changed.toJson());
      await provider.addSubject(
        'Kelas baru',
        0xFF123456,
        semester: UnpamCalendar.semester,
      );
      expect(
        provider.subjects.first.examBreaks.map((b) => b.toJson()),
        UnpamCalendar.examBreaks.map((b) => b.toJson()),
      );
    },
  );

  test(
    'payments and coursework persist atomically through concurrent edits and backup restoration',
    () async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await Future.wait([
        provider.addUnpamPayments(),
        provider.updateTask('subject', 'task', 'Judul tersimpan'),
      ]);
      await provider.setPaymentPaid(provider.payments.first.id, true);
      final backup = provider.exportData();
      expect(jsonDecode(backup)['version'], 2);
      final reopened = AppProvider();
      addTearDown(reopened.dispose);
      await reopened.waitUntilReady();
      expect(reopened.exportData(), backup);
      await provider.deleteSubject('subject');
      expect(provider.payments, hasLength(2));
      expect(await provider.importData(backup), true);
      expect(provider.subjects.single.tasks.single.title, 'Judul tersimpan');
      expect(provider.payments.first.isPaid, true);
      final before = provider.exportData();
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (d) => d['payments'][0]['amount'] = -1,
        (d) => d['payments'][0]['amount'] = 1.5,
        (d) => d['payments'][0]['amount'] = 1000000000001,
        (d) => d['payments'][0]['reminderMinutes'] = [-1],
        (d) => d['payments'][1]['id'] = d['payments'][0]['id'],
        (d) => d['version'] = 999,
      ]) {
        final data = jsonDecode(before) as Map<String, dynamic>;
        mutate(data);
        expect(await provider.importData(jsonEncode(data)), false);
        expect(provider.exportData(), before);
      }
      expect(await provider.importData(jsonEncode([sample().toJson()])), true);
      expect(provider.payments, isEmpty);
    },
  );

  test(
    'failed calendar and payment write cannot partially publish new dates or paid state',
    () async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      final before = provider.exportData();
      final store = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = RejectingStore(
        await store.getAll(),
      );
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      await expectLater(
        provider.applyUnpamCalendar(),
        throwsA(isA<StorageException>()),
      );
      expect(provider.exportData(), before);
      SharedPreferencesStorePlatform.instance = store;
      await provider.applyUnpamCalendar();
      final after = provider.exportData();
      SharedPreferencesStorePlatform.instance = RejectingStore(
        await store.getAll(),
      );
      await expectLater(
        provider.setPaymentPaid(provider.payments.first.id, true),
        throwsA(isA<StorageException>()),
      );
      expect(provider.exportData(), after);
    },
  );

  test(
    'payment reminders keep local time, ignore exam pauses, and cancel when paid',
    () {
      final p = TuitionPayment(
        id: 'payment',
        title: 'Cicilan',
        dueAt: DateTime(2026, 10, 22, 9),
        semester: UnpamCalendar.semester,
      );
      final subject = sample(
        tasks: [],
      ).copyWith(examBreaks: UnpamCalendar.examBreaks);
      final plan = planReminders(
        [subject],
        DateTime(2026, 10, 18),
        payments: [p],
      );
      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 19, 9),
        DateTime(2026, 10, 21, 9),
        DateTime(2026, 10, 22, 9),
      ]);
      expect(jsonDecode(plan.first.payload)['payment'], 'payment');
      expect(
        planReminders(
          [subject],
          DateTime(2026, 10, 18),
          payments: [p.copyWith(isPaid: true)],
        ),
        isEmpty,
      );
      expect(
        planReminders([subject], DateTime(2026, 10, 23), payments: [p]),
        isEmpty,
      );
    },
  );

  testWidgets(
    'custom installment saves amount, paid status, deletion and undo through UI',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider);
      PaymentsSheet.edit(
        tester.element(find.byType(DashboardScreen)),
        provider,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Angsuran ke-1');
      await tester.enterText(find.byType(TextFormField).at(1), '750000');
      await tester.ensureVisible(find.text('Simpan bayaran'));
      await tester.tap(find.text('Simpan bayaran'));
      await tester.pumpAndSettle();
      expect(provider.payments.single.amount, 750000);
      PaymentsSheet.show(
        tester.element(find.byType(DashboardScreen)),
        provider,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox).last);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(provider.payments.single.isPaid, true);
      final menu = find.byTooltip('Opsi bayaran Angsuran ke-1');
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus bayaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(provider.payments, isEmpty);
      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();
      expect(provider.payments.single.amount, 750000);
      expect(provider.payments.single.isPaid, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'academic preset and payment screens remain scrollable at large text',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await provider.applyUnpamCalendar();
      for (final scale in [1.0, 2.0]) {
        final key = GlobalKey();
        await showApp(
          tester,
          provider,
          size: const Size(393, 852),
          scale: scale,
          capture: key,
          home: DashboardScreen(provider: provider, initialTab: 2),
        );
        await tester.tap(find.text('Bayaran & cicilan'));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) await snapshot(tester, key, 'v2_bayaran');
        Navigator.of(tester.element(find.text('Bayaran & cicilan').last)).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kalender UNPAM Gasal 2026/2027'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Terapkan kalender UNPAM'));
        expect(tester.takeException(), isNull);
        Navigator.of(
          tester.element(find.text('Terapkan kalender UNPAM')),
        ).pop();
        await tester.pumpAndSettle();
      }
    },
  );
}
