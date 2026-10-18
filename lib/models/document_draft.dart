import 'academic_event.dart';
import 'subject.dart';
import 'tuition_payment.dart';

enum DocumentKind { automatic, schedule, payments, calendar }

enum StudyGroup {
  a('Reguler A', 'Kelas pagi · Kamis libur'),
  b('Reguler B', 'Kelas malam · Senin–Jumat'),
  ck('Reguler CK', 'Kuliah hanya Kamis'),
  cs('Reguler CS', 'Kuliah hanya Sabtu');

  final String label, description;
  const StudyGroup(this.label, this.description);

  bool allowsDay(String? day) => switch (this) {
    a => day != 'Kamis',
    b => !['Sabtu', 'Minggu'].contains(day),
    ck => day == 'Kamis',
    cs => day == 'Sabtu',
  };

  bool includesTitle(String title) {
    final groups = <String>{};
    for (final match in RegExp(
      r'\breg(?:uler)?\.?\s*(?:ck|cs|a|b)\b(?:\s*[&/,]\s*(?:reg(?:uler)?\.?\s*)?(?:ck|cs|a|b)\b)*',
      caseSensitive: false,
    ).allMatches(title)) {
      groups.addAll(
        RegExp(
          r'\b(?:ck|cs|a|b)\b',
        ).allMatches(match[0]!.toLowerCase()).map((m) => m[0]!),
      );
    }
    return groups.isEmpty || groups.contains(name);
  }
}

/// Coordinates use the top-left origin, in page units (points or pixels).
class DocumentWord {
  final String text;
  final double left, top, right, bottom;
  const DocumentWord(this.text, this.left, this.top, this.right, this.bottom);
  double get x => (left + right) / 2;
  double get y => (top + bottom) / 2;
  double get height => bottom - top;
}

class DocumentPage {
  final int number;
  final double width, height;
  final List<DocumentWord> words;
  final bool usedOcr;
  const DocumentPage(
    this.number,
    this.width,
    this.height,
    this.words, {
    this.usedOcr = false,
  });
}

class DocumentDraft {
  final String fileName, semester;
  final StudyGroup? studyGroup;
  final List<Subject> subjects;
  final List<TuitionPayment> payments;
  final List<AcademicEvent> events;
  final List<String> warnings;
  final Map<String, String> sources;
  final Set<String> needsReview;
  const DocumentDraft({
    required this.fileName,
    required this.semester,
    this.studyGroup,
    this.subjects = const [],
    this.payments = const [],
    this.events = const [],
    this.warnings = const [],
    this.sources = const {},
    this.needsReview = const {},
  });
  int get length => subjects.length + payments.length + events.length;

  Set<String> reviewForGroup(StudyGroup group) => {
    for (final s in subjects)
      if (!group.allowsDay(s.scheduleDay)) s.id,
    for (final p in payments)
      if (!group.includesTitle(p.title)) p.id,
    for (final e in events)
      if (!group.includesTitle(e.title)) e.id,
  };
}

String importName(String value) => value
    .toLowerCase()
    .replaceAll('projek', 'proyek')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();
