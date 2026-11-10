// ─────────────────────────────────────────────────────────────────────────────
//  date_utils.dart  –  Date & Duration Helpers
// ─────────────────────────────────────────────────────────────────────────────

import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class LeaveDateUtils {
  LeaveDateUtils._();

  // ── Formatters ─────────────────────────────────────────────────────────────
  static String formatDisplay(DateTime date) =>
      DateFormat(AppConstants.dateDisplay).format(date);

  static String formatISO(DateTime date) =>
      DateFormat(AppConstants.dateISO).format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat(AppConstants.dateTimeDisplay).format(date);

  // ── Parsers ────────────────────────────────────────────────────────────────
  static DateTime? parseISO(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateFormat(AppConstants.dateISO).parse(value);
    } catch (_) {
      return null;
    }
  }

  // ── Calculations ───────────────────────────────────────────────────────────

  /// Returns the number of working days (Mon–Fri) between [start] and [end],
  /// both dates inclusive.
  static int workingDays(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(last)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// Returns true if [date] is a weekend.
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  /// Returns relative time label (e.g. "2 days ago", "Just now").
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return formatDisplay(date);
  }

  /// Returns true if two date ranges overlap.
  static bool rangesOverlap(
    DateTime s1,
    DateTime e1,
    DateTime s2,
    DateTime e2,
  ) =>
      s1.isBefore(e2.add(const Duration(days: 1))) &&
      e1.isAfter(s2.subtract(const Duration(days: 1)));
}
