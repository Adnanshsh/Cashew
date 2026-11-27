import 'dart:math' as math;

DateTime cycleBoundary(int year, int month, int payday) {
  final last = DateTime(year, month + 1, 0);
  return DateTime(last.year, last.month, math.min(payday, last.day));
}

int calendarDays(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

class SpendingCycle {
  SpendingCycle(DateTime now, int payday) {
    today = DateTime(now.year, now.month, now.day);
    final offset =
        today.isBefore(cycleBoundary(now.year, now.month, payday)) ? -1 : 0;
    start = cycleBoundary(now.year, now.month + offset, payday);
    next = cycleBoundary(now.year, now.month + offset + 1, payday);
  }
  late final DateTime today, start, next;
  int get daysLeft => calendarDays(today, next);
  int get elapsed => calendarDays(start, today) + 1;

  double availableToday(double funds, double reserved, double priorSpend,
      double todaysSpend, double cap) {
    final allowance = math.max(0.0, funds - reserved - priorSpend) / daysLeft;
    return (cap > 0 ? math.min(allowance, cap) : allowance) - todaysSpend;
  }
}
