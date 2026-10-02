import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum UrgencyLevel { overdue, today, tomorrow, soon, future, textOnly, none }

class DeadlineInfo {
  final UrgencyLevel level;
  final String label;
  final int? daysRemaining;

  const DeadlineInfo({
    required this.level,
    required this.label,
    this.daysRemaining,
  });

  bool get isUrgent =>
      level == UrgencyLevel.overdue ||
      level == UrgencyLevel.today ||
      level == UrgencyLevel.tomorrow;

  Color getBadgeBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (level) {
      case UrgencyLevel.overdue:
        return isDark
            ? Colors.red.shade900.withValues(alpha: 0.5)
            : Colors.red.shade100;
      case UrgencyLevel.today:
        return isDark
            ? Colors.red.shade900.withValues(alpha: 0.4)
            : Colors.red.shade50;
      case UrgencyLevel.tomorrow:
        return isDark
            ? Colors.orange.shade900.withValues(alpha: 0.4)
            : Colors.orange.shade50;
      case UrgencyLevel.soon:
        return isDark
            ? Colors.amber.shade900.withValues(alpha: 0.3)
            : Colors.amber.shade50;
      case UrgencyLevel.future:
        return isDark
            ? Colors.blue.shade900.withValues(alpha: 0.3)
            : Colors.blue.shade50;
      case UrgencyLevel.textOnly:
      case UrgencyLevel.none:
        return isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    }
  }

  Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (level) {
      case UrgencyLevel.overdue:
        return isDark ? Colors.red.shade200 : Colors.red.shade800;
      case UrgencyLevel.today:
        return isDark ? Colors.red.shade300 : Colors.red.shade700;
      case UrgencyLevel.tomorrow:
        return isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      case UrgencyLevel.soon:
        return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
      case UrgencyLevel.future:
        return isDark ? Colors.blue.shade300 : Colors.blue.shade800;
      case UrgencyLevel.textOnly:
      case UrgencyLevel.none:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    }
  }

  IconData get icon {
    switch (level) {
      case UrgencyLevel.overdue:
        return Icons.warning_amber_rounded;
      case UrgencyLevel.today:
        return Icons.error_outline;
      case UrgencyLevel.tomorrow:
        return Icons.access_time_filled;
      case UrgencyLevel.soon:
        return Icons.access_time;
      case UrgencyLevel.future:
        return Icons.event;
      case UrgencyLevel.textOnly:
      case UrgencyLevel.none:
        return Icons.calendar_today_outlined;
    }
  }
}

class DeadlineHelper {
  static String? normalize(String? value, {DateTime? reference}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final now = reference ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final date = switch (text.toLowerCase()) {
      'hari ini' => day,
      'besok' => DateTime(day.year, day.month, day.day + 1),
      'kemarin' => DateTime(day.year, day.month, day.day - 1),
      'minggu ini' => DateTime(
        day.year,
        day.month,
        day.day + (7 - day.weekday),
      ),
      _ => parseDate(text),
    };
    return date == null ? text : DateFormat('yyyy-MM-dd').format(date);
  }

  static String display(String? value) {
    final date = parseDate(value);
    if (date == null) return value ?? '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static DeadlineInfo parse(String? deadline) {
    if (deadline == null || deadline.trim().isEmpty) {
      return const DeadlineInfo(level: UrgencyLevel.none, label: '');
    }

    final trimmed = deadline.trim();
    final lower = trimmed.toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Cek teks relatif umum
    if (lower == 'hari ini') {
      return const DeadlineInfo(
        level: UrgencyLevel.today,
        label: 'Hari ini!',
        daysRemaining: 0,
      );
    }
    if (lower == 'besok') {
      return const DeadlineInfo(
        level: UrgencyLevel.tomorrow,
        label: 'Besok',
        daysRemaining: 1,
      );
    }
    if (lower == 'kemarin') {
      return const DeadlineInfo(
        level: UrgencyLevel.overdue,
        label: 'Terlewat',
        daysRemaining: -1,
      );
    }
    if (lower.contains('minggu ini')) {
      return const DeadlineInfo(
        level: UrgencyLevel.soon,
        label: 'Minggu Ini',
        daysRemaining: 3,
      );
    }

    // Coba parsing tanggal terformat
    DateTime? parsedDate;
    final formats = [
      DateFormat('d MMM yyyy'),
      DateFormat('d MMMM yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d-M-yyyy'),
    ];

    for (final fmt in formats) {
      try {
        parsedDate = fmt.parseStrict(trimmed);
        break;
      } catch (_) {}
    }

    if (parsedDate != null) {
      final targetDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
      final daysDiff = targetDate.difference(today).inDays;

      if (daysDiff < 0) {
        return DeadlineInfo(
          level: UrgencyLevel.overdue,
          label: 'Terlewat ${-daysDiff} hari',
          daysRemaining: daysDiff,
        );
      } else if (daysDiff == 0) {
        return const DeadlineInfo(
          level: UrgencyLevel.today,
          label: 'Hari ini!',
          daysRemaining: 0,
        );
      } else if (daysDiff == 1) {
        return const DeadlineInfo(
          level: UrgencyLevel.tomorrow,
          label: 'Besok',
          daysRemaining: 1,
        );
      } else if (daysDiff <= 7) {
        return DeadlineInfo(
          level: UrgencyLevel.soon,
          label: '$daysDiff hari lagi',
          daysRemaining: daysDiff,
        );
      } else {
        return DeadlineInfo(
          level: UrgencyLevel.future,
          label: '$daysDiff hari lagi',
          daysRemaining: daysDiff,
        );
      }
    }

    // Default jika teks kustom seperti 'Sebelum UTS', 'Sebelum UAS'
    return DeadlineInfo(level: UrgencyLevel.textOnly, label: trimmed);
  }

  static DateTime? parseDate(String? deadline) {
    if (deadline == null || deadline.trim().isEmpty) return null;
    final trimmed = deadline.trim();
    final lower = trimmed.toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lower == 'hari ini') return today;
    if (lower == 'besok') return today.add(const Duration(days: 1));
    if (lower == 'kemarin') return today.subtract(const Duration(days: 1));

    final formats = [
      DateFormat('d MMM yyyy'),
      DateFormat('d MMMM yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d-M-yyyy'),
    ];

    for (final fmt in formats) {
      try {
        final parsed = fmt.parseStrict(trimmed);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }
    return null;
  }
}
