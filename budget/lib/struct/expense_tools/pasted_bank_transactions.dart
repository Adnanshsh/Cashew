import 'package:budget/database/tables.dart';
import 'package:budget/struct/expense_tools/bank_sms_parser.dart';
import 'package:drift/drift.dart';

/// A soft duplicate cue, never an automatic rejection. Two legitimate
/// purchases may share an amount on the same day.
Future<Transaction?> findSimilarBankTransaction(
    FinanceDatabase db, String wallet, DateTime date, ParsedBankSms parsed) {
  final day = DateTime(date.year, date.month, date.day);
  final nextDay = DateTime(day.year, day.month, day.day + 1);
  final signed = parsed.income ? parsed.amount : -parsed.amount;
  return (db.select(db.transactions)
        ..where((row) =>
            row.walletFk.equals(wallet) &
            row.income.equals(parsed.income) &
            row.paid.equals(true) &
            row.pairedTransactionFk.isNull() &
            row.categoryFk.equals('0').not() &
            row.amount.isBiggerThanValue(signed - 0.0005) &
            row.amount.isSmallerThanValue(signed + 0.0005) &
            row.dateCreated.isBiggerOrEqualValue(day) &
            row.dateCreated.isSmallerThanValue(nextDay))
        ..limit(1))
      .getSingleOrNull();
}
