import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart';

Future<void>? _initialization;

// Capture the original digit ranges before replacing the mutable intl symbols.
// Keep them available when parsing older exports or localized keyboard input.
final Set<int> _nativeZeroDigits = numberFormatSymbols.values
    .cast<NumberSymbols>()
    .map((symbols) => symbols.ZERO_DIGIT.runes.single)
    .where((zero) => zero != 0x30)
    .toSet();

/// Normalize decimal digits at numeric/date input boundaries, preserving text
/// and separators. This does not alter stored transaction names or notes.
String toWesternDigits(String value) =>
    _replaceDigits(value, _nativeZeroDigits);

/// Keep translated text and locale-specific formatting, but display 0-9 digits.
///
/// Call before creating any formatters or loading Material localizations:
/// NumberFormat and Flutter's localization delegates cache their formatters.
Future<void> initializeWesternDigits() =>
    _initialization ??= _initializeWesternDigits();

Future<void> _initializeWesternDigits() async {
  await initializeDateFormatting();
  for (final locale in DateFormat.allLocalesWithSymbols()) {
    DateFormat.useNativeDigitsByDefaultFor(locale, false);
  }

  final nativeZeros = _nativeZeroDigits;

  final symbolsByLocale = numberFormatSymbols.cast<String, NumberSymbols>();
  symbolsByLocale.updateAll((locale, symbols) {
    // Some scientific exponent symbols contain literal native digits (e.g. fa).
    final exponent = _replaceDigits(symbols.EXP_SYMBOL, nativeZeros);
    if (symbols.ZERO_DIGIT == '0' && exponent == symbols.EXP_SYMBOL) {
      return symbols;
    }
    return NumberSymbols(
      NAME: symbols.NAME,
      DECIMAL_SEP: symbols.DECIMAL_SEP,
      GROUP_SEP: symbols.GROUP_SEP,
      PERCENT: symbols.PERCENT,
      ZERO_DIGIT: '0',
      PLUS_SIGN: symbols.PLUS_SIGN,
      MINUS_SIGN: symbols.MINUS_SIGN,
      EXP_SYMBOL: exponent,
      PERMILL: symbols.PERMILL,
      INFINITY: symbols.INFINITY,
      NAN: symbols.NAN,
      DECIMAL_PATTERN: symbols.DECIMAL_PATTERN,
      SCIENTIFIC_PATTERN: symbols.SCIENTIFIC_PATTERN,
      PERCENT_PATTERN: symbols.PERCENT_PATTERN,
      CURRENCY_PATTERN: symbols.CURRENCY_PATTERN,
      DEF_CURRENCY_CODE: symbols.DEF_CURRENCY_CODE,
    );
  });
}

String _replaceDigits(String value, Set<int> nativeZeros) {
  return String.fromCharCodes(value.runes.map((rune) {
    for (final zero in nativeZeros) {
      if (rune >= zero && rune <= zero + 9) return 0x30 + rune - zero;
    }
    return rune;
  }));
}
