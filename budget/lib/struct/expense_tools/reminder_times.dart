const defaultExpenseReminderMinutes = <int>[600, 840, 1080, 1320];
const expenseReminderIdBase = 600000000;

List<int> expenseReminderMinutes(dynamic stored) {
  if (stored is! List ||
      stored.length != 4 ||
      stored.any((value) => value is! int || value < 0 || value >= 1440)) {
    return List.of(defaultExpenseReminderMinutes);
  }
  final values = stored.cast<int>().toSet().toList()..sort();
  return values.length == 4 ? values : List.of(defaultExpenseReminderMinutes);
}
