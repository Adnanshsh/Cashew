import 'package:budget/struct/expense_tools/spending_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('month end payday clamps across leap and short months', () {
    final c = SpendingCycle(DateTime(2024, 2, 28), 31);
    expect(c.start, DateTime(2024, 1, 31));
    expect(c.next, DateTime(2024, 2, 29));
    expect(c.daysLeft, 1);
    expect(
        SpendingCycle(DateTime(2025, 2, 28), 31).next, DateTime(2025, 3, 31));
  });
  test('reserve, daily cap and spending apply once', () {
    final c = SpendingCycle(DateTime(2026, 11, 11), 1);
    expect(c.daysLeft, 20);
    expect(c.availableToday(1000, 200, 200, 12, 0), 18);
    expect(c.availableToday(1000, 200, 200, 25, 20), -5);
  });
}
