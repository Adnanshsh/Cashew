import 'package:budget/struct/westernDigits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NumberSymbols originalArabicSymbols;
  late Set<int> nativeZeros;

  bool containsNativeDigit(String value) => value.runes.any(
      (rune) => nativeZeros.any((zero) => rune >= zero && rune <= zero + 9));

  setUpAll(() async {
    originalArabicSymbols = numberFormatSymbols['ar']!;
    nativeZeros = numberFormatSymbols.values
        .cast<NumberSymbols>()
        .map((symbols) => symbols.ZERO_DIGIT.runes.single)
        .where((zero) => zero != 0x30)
        .toSet();
    await initializeWesternDigits();
  });

  test('Arabic amounts keep separators and currency text with western digits',
      () {
    final decimal = NumberFormat.decimalPattern('ar');
    final amount = decimal.format(1234.5);
    expect(amount, contains('1'));
    expect(amount, contains(originalArabicSymbols.DECIMAL_SEP));
    expect(amount, contains(originalArabicSymbols.GROUP_SEP));
    expect(containsNativeDigit(amount), isFalse);

    final currency = NumberFormat.currency(
      locale: 'ar',
      name: 'LYD',
      symbol: 'د.ل',
    ).format(1234.5);
    expect(currency, contains('د.ل'));
    expect(currency, contains('1'));
    expect(containsNativeDigit(currency), isFalse);
  });

  test('Arabic dates and times retain Arabic month text', () {
    final date = DateTime(2026, 11, 14, 9, 5, 7);
    final formattedDate = DateFormat.yMMMMd('ar').format(date);
    final formattedTime = DateFormat.Hms('ar').format(date);
    expect(formattedDate, contains('نوفمبر'));
    expect(formattedDate, contains('2026'));
    expect(formattedDate, contains('14'));
    expect(formattedTime, '09:05:07');
    expect(containsNativeDigit(formattedDate), isFalse);
  });

  test('Material Arabic calendar and time labels use western digits', () async {
    // Flutter initializes its own date-symbol data when this delegate loads.
    final material =
        await GlobalMaterialLocalizations.delegate.load(const Locale('ar'));
    final widgets =
        await GlobalWidgetsLocalizations.delegate.load(const Locale('ar'));
    final date = DateTime(2026, 11, 14);

    expect(material.formatDecimal(123), '123');
    expect(material.formatYear(date), '2026');
    expect(material.formatMonthYear(date), contains('نوفمبر'));
    expect(containsNativeDigit(material.formatFullDate(date)), isFalse);
    expect(material.formatHour(const TimeOfDay(hour: 9, minute: 5)), '9');
    expect(material.formatMinute(const TimeOfDay(hour: 9, minute: 5)), '05');
    expect(
      containsNativeDigit(
          material.formatTimeOfDay(const TimeOfDay(hour: 9, minute: 5))),
      isFalse,
    );
    expect(material.cancelButtonLabel, contains('إلغاء'));
    expect(widgets.textDirection, TextDirection.rtl);
    final compact = material.formatCompactDate(date);
    expect(material.parseCompactDate(compact), date);
  });

  test('Persian and Bengali formats use western digits too', () {
    for (final locale in ['fa', 'bn']) {
      final decimal = NumberFormat.decimalPattern(locale).format(1234.5);
      final scientific = NumberFormat.scientificPattern(locale).format(1000);
      final date = DateFormat.yMd(locale).format(DateTime(2026, 11, 14));
      expect(decimal, contains('1'), reason: locale);
      expect(containsNativeDigit(decimal), isFalse, reason: locale);
      expect(containsNativeDigit(scientific), isFalse, reason: locale);
      expect(containsNativeDigit(date), isFalse, reason: locale);
    }
  });

  test('registered number locales all produce western decimal digits', () {
    for (final locale in numberFormatSymbols.keys) {
      final amount = NumberFormat.decimalPattern(locale).format(1234.5);
      expect(amount, contains('1'), reason: locale);
      expect(containsNativeDigit(amount), isFalse, reason: locale);
    }
  });

  test('registered date locales all produce western date and time digits', () {
    final date = DateTime(2026, 11, 14, 9, 5, 7);
    for (final locale in DateFormat.allLocalesWithSymbols()) {
      final text = DateFormat('yyyy/MM/dd HH:mm:ss', locale).format(date);
      expect(text, contains('2026'), reason: locale);
      expect(text, contains('09:05:07'), reason: locale);
      expect(containsNativeDigit(text), isFalse, reason: locale);
    }
  });

  test('western negative decimals round trip through localized parsers', () {
    for (final locale in ['ar', 'fa', 'bn', 'en_US', 'de']) {
      final format = NumberFormat.decimalPattern(locale);
      final text = format.format(-1234.5);
      expect(containsNativeDigit(text), isFalse, reason: locale);
      expect(format.parse(text), -1234.5, reason: locale);
    }
  });

  test('localized date input remains parseable after the display policy', () {
    final inputs = {
      'ar': '٢٠٢٦/١١/١٩',
      'fa': '۲۰۲۶/۱۱/۱۹',
      'bn': '২০২৬/১১/১৯',
    };
    for (final entry in inputs.entries) {
      final normalized = toWesternDigits(entry.value);
      expect(normalized, '2026/11/19', reason: entry.key);
      expect(
        DateFormat('yyyy/MM/dd', entry.key).parseStrict(normalized),
        DateTime(2026, 11, 19),
        reason: entry.key,
      );
    }
  });

  test('input normalization preserves letters separators and ASCII digits', () {
    expect(
      toWesternDigits('Invoice A20: ١٢٫٥ د.ل - ۴۲ / ১২'),
      'Invoice A20: 12٫5 د.ل - 42 / 12',
    );
    expect(toWesternDigits('Invoice A20 / 2026-11-19'),
        'Invoice A20 / 2026-11-19');
    expect(toWesternDigits('اسم الحساب'), 'اسم الحساب');
  });

  test('initialization is safe to repeat and preserves existing formatters',
      () async {
    final formatter = NumberFormat.currency(locale: 'ar', name: 'LYD');
    final before = formatter.format(10.5);
    await initializeWesternDigits();
    await initializeWesternDigits();
    expect(formatter.format(10.5), before);
    expect(containsNativeDigit(before), isFalse);
    expect(
        DateFormat.yMd('ar').format(DateTime(2026, 11, 14)), contains('2026'));
  });
}
