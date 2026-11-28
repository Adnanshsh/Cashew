import 'package:budget/struct/expense_tools/bank_sms_parser.dart';
import 'package:budget/struct/expense_tools/reminder_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('North Africa debit uses amount, never balance or account number', () {
    final result = parseBankSms('18888',
        'تم خصم مبلغ ١٢٥٫٥٠٠ دينار من حسابك 123456789. الرصيد ٨٨٨٨٫٠٠٠ دينار');
    expect(result?.amount, 125.5);
    expect(result?.income, false);
    expect(result?.bank, 'شمال أفريقيا');
  });
  test('Development credit keeps LYD three decimal precision', () {
    final result = parseBankSms(
        '18787', 'تم إضافة مبلغ ٣٠٠٫٢٥٠ د.ل إلى حسابكم، الرصيد 1000.000 د.ل');
    expect(result?.amount, 300.25);
    expect(result?.income, true);
    expect(result?.bank, 'التنمية');
  });
  test('NCB alphanumeric sender and English debit are supported', () {
    final result = parseBankSms(' ncb ',
        'Your account 555 has been debited LYD 45.25. Available balance LYD 850.50');
    expect(result?.amount, 45.25);
    expect(result?.income, false);
    expect(result?.bank, 'التجاري');
  });
  test('English credit with grouped amount parses unambiguously', () {
    final result = parseBankSms('NCB',
        'Credited 1,234.500 LYD to account 123456. Balance 9,000.000 LYD');
    expect(result?.amount, 1234.5);
    expect(result?.income, true);
  });
  test('refunds with a clear amount are credits', () {
    final refund = parseBankSms('NCB', 'Refunded LYD 35.500 to your card');
    expect(refund?.income, true);
    expect(refund?.amount, 35.5);
    expect(parseBankSms('18888', 'تم استرداد مبلغ ١٢٫٥ دينار')?.income, true);
  });
  test('exact senders only; lookalikes and unknown banks are rejected', () {
    for (final sender in [
      '+21818888',
      '188888',
      'NCB-BANK',
      'Contact NCB',
      '99999'
    ]) {
      expect(parseBankSms(sender, 'تم خصم مبلغ 50 دينار'), isNull,
          reason: sender);
    }
  });
  test('OTP, balance-only and ambiguous direction require manual review', () {
    for (final text in [
      'تم خصم مبلغ 20 دينار رمز التحقق 123456',
      'OTP 123456 to confirm purchase 20 LYD',
      'الرصيد المتاح 2000 دينار',
      'تم خصم 25 دينار وتم إضافة 20 دينار',
      'تم سحب من حساب 123456789 بتاريخ 2026/11/19',
      'تم خصم مبلغ 1,234 دينار',
      'تم خصم مبلغ 20 دينار ومبلغ 40 دينار',
      'تم خصم 1,234 دينار ومبلغ 25 دينار',
    ]) {
      expect(parseBankSms('18888', text), isNull, reason: text);
    }
  });
  test('transaction amount before separate fee is preserved', () {
    expect(
        parseBankSms('18888', 'تم سحب مبلغ 100 دينار الرسوم 2 دينار')?.amount,
        100);
  });
  test(
      'explicit amount label can work without currency but not bare account digits',
      () {
    expect(
        parseBankSms('18787', 'تم إضافة مبلغ 500.250 إلى حسابك 123456')?.amount,
        500.25);
    expect(parseBankSms('18787', 'تم إضافة مستفيد بحساب 123456'), isNull);
  });
  test('pasted bank messages work without a verified sender', () {
    final debit = parsePastedBankSms(
        'تم خصم مبلغ ٤٢٫٥٠٠ د.ل من بطاقتك 1234، الرصيد 300.000 د.ل');
    expect(debit?.amount, 42.5);
    expect(debit?.income, false);
    final deposit = parsePastedBankSms('Credited LYD 100.250 to account 555');
    expect(deposit?.amount, 100.25);
    expect(deposit?.income, true);
  });
  test(
      'pasted messages do not infer currency, guess foreign amounts or parse OTPs',
      () {
    for (final text in [
      'تم خصم مبلغ 50 من الحساب',
      'تم خصم مبلغ 50 دينار تونسي',
      'Purchase of USD 10 converted to 45 LYD',
      'Purchase 20 LYD; OTP 123456',
      'الرصيد 200 دينار ليبي',
      'Purchase 2.1234 LYD',
      'تم خصم 10 دينار وتم إضافة 20 دينار',
    ]) {
      expect(parsePastedBankSms(text), isNull, reason: text);
    }
  });
  test('instant category capture only parses a known, clear LYD debit', () {
    final text = 'تم خصم مبلغ ٤٢٫٥٠٠ د.ل من بطاقتك، الرصيد 300 د.ل';
    final debit = parseBankSmsQuickDebit('18888', text);
    expect(debit?.amount, 42.5);
    expect(debit?.sender, '18888');
    expect(parseBankSmsQuickDebit('unknown', text), isNull);
    for (final invalid in [
      'Credited 12 LYD to your account',
      'Purchase of USD 10 converted to 45 LYD',
      'تم خصم مبلغ 50 من الحساب',
      'Purchase 20 LYD; OTP 123456',
      'تم خصم 20 دينار وتم إضافة 10 دينار',
    ]) {
      expect(parseBankSmsQuickDebit('18888', invalid), isNull, reason: invalid);
    }
  });
  test('four reminder slots normalize, persist and reject invalid settings',
      () {
    expect(expenseReminderMinutes(null), [600, 840, 1080, 1320]);
    expect(
        expenseReminderMinutes([1320, 600, 1080, 840]), [600, 840, 1080, 1320]);
    for (final invalid in [
      [],
      [600, 600, 1080, 1320],
      [0, 500, 900, 1440],
      ['10', 840, 1080, 1320]
    ]) {
      expect(expenseReminderMinutes(invalid), defaultExpenseReminderMinutes);
    }
    expect(expenseReminderMinutes([0, 1, 1438, 1439]), [0, 1, 1438, 1439]);
  });
}
