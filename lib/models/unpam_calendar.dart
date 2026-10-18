import 'academic_schedule.dart';
import 'tuition_payment.dart';

/// Acuan: kalender akademik UNPAM Gasal 2026/2027 yang diberikan pengguna.
class UnpamCalendar {
  static const semester = 'UNPAM Gasal 2026/2027';
  static final start = DateTime(2026, 8, 31);
  static final end = DateTime(2027, 2, 6);
  // Default praktis sebelum pekan UAS, tetap dapat diubah sesuai jadwal dosen.
  static final mentariEnd = DateTime(2026, 12, 13);

  static bool isCurrent(DateTime now) =>
      !calendarDay(now).isBefore(start) && !calendarDay(now).isAfter(end);

  static List<ExamBreak> get examBreaks => [
    ExamBreak(
      name: 'UTS',
      start: DateTime(2026, 10, 19),
      end: DateTime(2026, 10, 24),
    ),
    ExamBreak(
      name: 'UAS',
      start: DateTime(2026, 12, 14),
      end: DateTime(2026, 12, 19),
    ),
  ];

  static List<TuitionPayment> get payments => [
    TuitionPayment(
      id: 'unpam_2026_gasal_uts',
      title: 'Angsuran ke-3 & UTS · Reg. A/B',
      dueAt: DateTime(2026, 10, 13, 9),
      semester: semester,
    ),
    TuitionPayment(
      id: 'unpam_2026_gasal_uas',
      title: 'Pelunasan biaya kuliah & UAS · Reg. A/B',
      dueAt: DateTime(2026, 12, 8, 9),
      semester: semester,
    ),
  ];

  static final events = <({String title, DateTime start, DateTime end})>[
    (
      title: 'Awal kuliah Reg. A/B & CK/CS kelompok MK 2',
      start: start,
      end: start,
    ),
    (
      title: 'Awal kuliah Reg. CK kelompok MK 1',
      start: DateTime(2026, 9, 3),
      end: DateTime(2026, 9, 3),
    ),
    (
      title: 'Awal kuliah Reg. CS kelompok MK 1',
      start: DateTime(2026, 9, 5),
      end: DateTime(2026, 9, 5),
    ),
    (
      title: 'Pendaftaran UTS susulan',
      start: DateTime(2026, 10, 19),
      end: DateTime(2026, 10, 27),
    ),
    (
      title: 'Pelaksanaan UTS susulan',
      start: DateTime(2026, 10, 29),
      end: DateTime(2026, 10, 29),
    ),
    (
      title: 'Pelaksanaan UTS susulan',
      start: DateTime(2026, 10, 31),
      end: DateTime(2026, 10, 31),
    ),
    (
      title: 'Pendaftaran UTS revisi & UAS susulan/revisi',
      start: DateTime(2026, 12, 14),
      end: DateTime(2027, 1, 2),
    ),
    (
      title: 'Libur akhir tahun',
      start: DateTime(2026, 12, 26),
      end: DateTime(2026, 12, 31),
    ),
    (
      title: 'Tahun Baru Masehi',
      start: DateTime(2027, 1, 1),
      end: DateTime(2027, 1, 1),
    ),
    (
      title: 'Isra Mikraj Nabi Muhammad SAW',
      start: DateTime(2027, 1, 5),
      end: DateTime(2027, 1, 5),
    ),
    (
      title: 'Pelaksanaan UTS revisi & UAS susulan/revisi',
      start: DateTime(2027, 1, 7),
      end: DateTime(2027, 1, 7),
    ),
    (
      title: 'Pelaksanaan UTS revisi & UAS susulan/revisi',
      start: DateTime(2027, 1, 9),
      end: DateTime(2027, 1, 9),
    ),
    (
      title: 'Herregistrasi mahasiswa lama',
      start: DateTime(2027, 1, 18),
      end: DateTime(2027, 1, 26),
    ),
    (
      title: 'Edit jadwal di SIA',
      start: DateTime(2027, 2, 4),
      end: DateTime(2027, 2, 9),
    ),
    (
      title: 'Batas akhir semester gasal (kalender mencantumkan 5 & 6 Feb)',
      start: DateTime(2027, 2, 5),
      end: DateTime(2027, 2, 6),
    ),
    (
      title: 'Tahun Baru Imlek',
      start: DateTime(2027, 2, 6),
      end: DateTime(2027, 2, 6),
    ),
    (
      title: 'Libur awal puasa',
      start: DateTime(2027, 2, 8),
      end: DateTime(2027, 2, 9),
    ),
    (
      title: 'Revisi KRS',
      start: DateTime(2027, 2, 10),
      end: DateTime(2027, 2, 13),
    ),
    (
      title: 'Awal semester genap Reg. A/B & CK/CS kelompok MK 2',
      start: DateTime(2027, 2, 15),
      end: DateTime(2027, 2, 15),
    ),
    (
      title: 'Awal semester genap Reg. CK kelompok MK 1',
      start: DateTime(2027, 2, 18),
      end: DateTime(2027, 2, 18),
    ),
    (
      title: 'Awal semester genap Reg. CS kelompok MK 1',
      start: DateTime(2027, 2, 20),
      end: DateTime(2027, 2, 20),
    ),
  ];

  static List<String> eventsOn(DateTime date) => [
    for (final event in events)
      if (!calendarDay(date).isBefore(event.start) &&
          !calendarDay(date).isAfter(event.end))
        event.title,
  ];
}
