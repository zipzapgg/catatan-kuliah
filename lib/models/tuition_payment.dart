import 'academic_schedule.dart';

class TuitionPayment {
  static const _unchanged = Object();
  final String id, title, semester;
  final DateTime? dueAt, paidAt;
  final int? amount;
  final bool isPaid;
  final List<int> reminderMinutes;

  const TuitionPayment({
    required this.id,
    required this.title,
    this.dueAt,
    this.paidAt,
    required this.semester,
    this.amount,
    this.isPaid = false,
    this.reminderMinutes = const [4320, 1440, 0],
  });

  void validate() {
    if (id.trim().isEmpty ||
        id.length > 500 ||
        title.trim().isEmpty ||
        title.length > 200 ||
        semester.length > 100 ||
        (dueAt != null && (dueAt!.year < 2020 || dueAt!.year > 2100)) ||
        (paidAt != null && (paidAt!.year < 2020 || paidAt!.year > 2100)) ||
        (amount != null && (amount! < 0 || amount! > 1000000000000)) ||
        reminderMinutes.length > 5 ||
        reminderMinutes.any((m) => m < 0 || m > 10080)) {
      throw const FormatException(
        'Data bayaran tidak valid. Periksa judul, tanggal, dan nominal rupiah.',
      );
    }
  }

  TuitionPayment copyWith({
    String? id,
    String? title,
    String? semester,
    Object? dueAt = _unchanged,
    Object? paidAt = _unchanged,
    Object? amount = _unchanged,
    bool? isPaid,
    List<int>? reminderMinutes,
  }) => TuitionPayment(
    id: id ?? this.id,
    title: title ?? this.title,
    semester: semester ?? this.semester,
    dueAt: identical(dueAt, _unchanged) ? this.dueAt : dueAt as DateTime?,
    paidAt: identical(paidAt, _unchanged) ? this.paidAt : paidAt as DateTime?,
    amount: identical(amount, _unchanged) ? this.amount : amount as int?,
    isPaid: isPaid ?? this.isPaid,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'semester': semester,
    'dueAt': dueAt?.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'amount': amount,
    'isPaid': isPaid,
    'reminderMinutes': reminderMinutes,
  };

  factory TuitionPayment.fromJson(Map<String, dynamic> json) => TuitionPayment(
    id: json['id'] as String,
    title: json['title'] as String,
    semester: json['semester'] as String,
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.parse(json['dueAt'] as String),
    paidAt: json['paidAt'] == null
        ? null
        : DateTime.parse(json['paidAt'] as String),
    amount: json['amount'] as int?,
    isPaid: json['isPaid'] as bool,
    reminderMinutes: (json['reminderMinutes'] as List).cast<int>(),
  )..validate();

  bool isOverdue(DateTime now) =>
      !isPaid &&
      dueAt != null &&
      calendarDay(dueAt!).isBefore(calendarDay(now));
}
