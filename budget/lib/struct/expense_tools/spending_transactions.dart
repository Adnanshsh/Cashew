import 'package:budget/database/tables.dart';
import 'package:drift/drift.dart';
import 'package:budget/struct/expense_tools/spending_cycle.dart';

Stream<List<Transaction>> watchSpendingCycle(
    FinanceDatabase db, String wallet, SpendingCycle cycle) {
  return (db.select(db.transactions)
        ..where((t) =>
            t.walletFk.equals(wallet) &
            t.categoryFk.equals('0').not() &
            t.skipPaid.equals(false) &
            t.dateCreated.isBiggerOrEqualValue(cycle.start) &
            t.dateCreated.isSmallerThanValue(cycle.next)))
      .watch();
}
