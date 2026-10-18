import 'academic_schedule.dart';

class AcademicEvent {
  final String id, title, semester, kind;
  final DateTime start, end;
  const AcademicEvent({
    required this.id,
    required this.title,
    required this.semester,
    required this.start,
    required this.end,
    this.kind = 'event',
  });

  void validate() {
    if (id.isEmpty ||
        id.length > 500 ||
        title.trim().isEmpty ||
        title.length > 300 ||
        semester.trim().isEmpty ||
        semester.length > 100 ||
        !['event', 'UTS', 'UAS'].contains(kind) ||
        start.year < 2020 ||
        end.year > 2100 ||
        end.isBefore(start) ||
        end.difference(start).inDays > 366) {
      throw const FormatException(
        'Periksa judul, semester, dan tanggal kegiatan.',
      );
    }
  }

  bool contains(DateTime day) =>
      !calendarDay(day).isBefore(calendarDay(start)) &&
      !calendarDay(day).isAfter(calendarDay(end));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'semester': semester,
    'kind': kind,
    'start': dateKey(start),
    'end': dateKey(end),
  };
  factory AcademicEvent.fromJson(Map<String, dynamic> json) => AcademicEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    semester: json['semester'] as String,
    kind: json['kind'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
  )..validate();
}
