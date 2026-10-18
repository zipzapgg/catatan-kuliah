DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime shiftDays(DateTime value, int days) => DateTime(
  value.year,
  value.month,
  value.day + days,
  value.hour,
  value.minute,
);

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

bool isWebLink(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

class ExamBreak {
  final String name;
  final DateTime start;
  final DateTime end;
  const ExamBreak({required this.name, required this.start, required this.end});

  bool contains(DateTime date) =>
      !calendarDay(date).isBefore(calendarDay(start)) &&
      !calendarDay(date).isAfter(calendarDay(end));
  bool overlaps(DateTime from, DateTime to) =>
      !calendarDay(to).isBefore(calendarDay(start)) &&
      !calendarDay(from).isAfter(calendarDay(end));

  void validate() {
    if (!['UTS', 'UAS'].contains(name) || end.isBefore(start)) {
      throw const FormatException('Periode UTS/UAS tidak valid.');
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'start': dateKey(start),
    'end': dateKey(end),
  };
  factory ExamBreak.fromJson(Map<String, dynamic> json) => ExamBreak(
    name: json['name'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
  )..validate();
}

class MentariOccurrence {
  final DateTime start;
  final DateTime deadline;
  final bool isDone;
  const MentariOccurrence(this.start, this.deadline, this.isDone);
  String get key => dateKey(start);
}

class MentariSchedule {
  final DateTime firstStart;
  final DateTime firstDeadline;
  final DateTime until;
  final int intervalWeeks;
  final String url;
  final List<int> reminderMinutes;
  final List<String> completed;

  const MentariSchedule({
    required this.firstStart,
    required this.firstDeadline,
    required this.until,
    this.intervalWeeks = 2,
    this.url = '',
    this.reminderMinutes = const [1440, 60],
    this.completed = const [],
  });

  void validate() {
    if (![1, 2].contains(intervalWeeks) ||
        !firstDeadline.isAfter(firstStart) ||
        calendarDay(until).isBefore(calendarDay(firstDeadline)) ||
        calendarDay(until).isAfter(shiftDays(calendarDay(firstStart), 366)) ||
        firstDeadline.isAfter(shiftDays(firstStart, 28))) {
      throw const FormatException(
        'Deadline harus setelah mulai dan sebelum akhir perkuliahan. Periode maksimal satu tahun.',
      );
    }
    if (url.isNotEmpty && !isWebLink(url)) {
      throw const FormatException(
        'Gunakan tautan Mentari dengan https:// atau http://.',
      );
    }
    if (reminderMinutes.length > 5 ||
        reminderMinutes.any((m) => m < 0 || m > 10080) ||
        completed.length > 400 ||
        completed.any((s) => DateTime.tryParse(s) == null)) {
      throw const FormatException('Data pengingat Mentari tidak valid.');
    }
  }

  List<MentariOccurrence> occurrences({
    required DateTime from,
    required DateTime to,
    List<ExamBreak> breaks = const [],
  }) {
    validate();
    final result = <MentariOccurrence>[];
    for (var offset = 0; ; offset += intervalWeeks * 7) {
      final start = shiftDays(firstStart, offset);
      if (calendarDay(start).isAfter(calendarDay(until)) || start.isAfter(to)) {
        break;
      }
      final deadline = shiftDays(firstDeadline, offset);
      if (calendarDay(deadline).isAfter(calendarDay(until))) {
        break;
      }
      if (deadline.isBefore(from) ||
          breaks.any((b) => b.overlaps(start, deadline))) {
        continue;
      }
      result.add(
        MentariOccurrence(start, deadline, completed.contains(dateKey(start))),
      );
    }
    return result;
  }

  MentariSchedule withCompletion(String key, bool done) => MentariSchedule(
    firstStart: firstStart,
    firstDeadline: firstDeadline,
    until: until,
    intervalWeeks: intervalWeeks,
    url: url,
    reminderMinutes: reminderMinutes,
    completed: {...completed.where((s) => s != key), if (done) key}.toList(),
  );

  Map<String, dynamic> toJson() => {
    'firstStart': firstStart.toIso8601String(),
    'firstDeadline': firstDeadline.toIso8601String(),
    'until': dateKey(until),
    'intervalWeeks': intervalWeeks,
    'url': url,
    'reminderMinutes': reminderMinutes,
    'completed': completed,
  };
  factory MentariSchedule.fromJson(Map<String, dynamic> json) =>
      MentariSchedule(
        firstStart: DateTime.parse(json['firstStart'] as String),
        firstDeadline: DateTime.parse(json['firstDeadline'] as String),
        until: DateTime.parse(json['until'] as String),
        intervalWeeks: json['intervalWeeks'] as int,
        url: json['url'] as String? ?? '',
        reminderMinutes: (json['reminderMinutes'] as List).cast<int>(),
        completed: (json['completed'] as List? ?? []).cast<String>(),
      )..validate();
}
