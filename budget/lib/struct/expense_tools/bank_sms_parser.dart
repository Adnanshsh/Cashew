/// Sender names are exact matches; a contact or a longer number must not match.
const bankSmsSenders = <String, String>{
  '18888': 'شمال أفريقيا',
  '18787': 'التنمية',
  'NCB': 'التجاري',
};

String normalizeBankSender(String sender) => sender.trim().toUpperCase();

String normalizeBankText(String input) {
  var text = input.replaceAll(RegExp('[\\u200e\\u200f\\u061c]'), '');
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll(String.fromCharCode(0x660 + i), '$i');
    text = text.replaceAll(String.fromCharCode(0x6f0 + i), '$i');
  }
  return text
      .replaceAll('٫', '.')
      .replaceAll('٬', ',')
      .replaceAll(RegExp('[\\u064b-\\u065f\\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا');
}

class ParsedBankSms {
  const ParsedBankSms(
      {required this.sender, required this.amount, required this.income});
  final String sender;
  final double amount;
  final bool income;
  String get bank => bankSmsSenders[sender]!;
}

/// Conservative extraction: never interpret a balance, OTP, card or account
/// number as the transaction amount. Unrecognized messages remain reviewable.
ParsedBankSms? parseBankSms(String sender, String body) {
  sender = normalizeBankSender(sender);
  if (!bankSmsSenders.containsKey(sender)) return null;
  var text = normalizeBankText(body).toLowerCase();
  if (RegExp(
          r'\botp\b|one.?time|verification|رمز التحقق|رمز التاكيد|كلمة المرور')
      .hasMatch(text)) return null;
  // Balance and fee sections are not transaction amount candidates.
  text = text
      .split(RegExp(
          r'الرصيد|رصيدك|رصيد حسابك|available balance|current balance|balance|العمولة|الرسوم|fees?\b'))
      .first;
  final debit = RegExp(
      r'تم\s+(?:خصم|سحب|دفع)|خصم|سحب|مدين|عملية شراء|تم الشراء|\bdebit(?:ed)?\b|\bwithdraw(?:al|n)?\b|\bpurchase\b|\bspent\b');
  final credit = RegExp(
      r'تم\s+(?:اضافة|ايداع|تغذية)|اضيف|اضافة|ايداع|دائن|حوالة واردة|\bcredit(?:ed)?\b|\bdeposit(?:ed)?\b|\breceived\b');
  final out = debit.firstMatch(text);
  final incoming = credit.firstMatch(text);
  if ((out == null) == (incoming == null)) return null;
  final direction = (out ?? incoming)!;
  final tail = text.substring(direction.end);
  const number = r'([0-9]+(?:[,.][0-9]+)*)';
  const currency = r'(?:د\s*\.?\s*ل\.?|دينار(?:ا)?|\b(?:lyd|l\.d\.?|ld)\b)';
  final candidates = <String>[];
  // Require a currency or an explicit amount label, not a bare number.
  final currencyAfter = RegExp('$number\\s*$currency', caseSensitive: false);
  final currencyBefore = RegExp('$currency\\s*$number', caseSensitive: false);
  candidates.addAll(currencyAfter.allMatches(tail).map((m) => m.group(1)!));
  candidates.addAll(currencyBefore.allMatches(tail).map((m) => m.group(1)!));
  if (candidates.isEmpty) {
    final labelled = RegExp(
            '^(?:\\s|[:،,-])*(?:مبلغ|بقيمة|بمبلغ|amount(?: of)?)\\s*[:=]?\\s*$number',
            caseSensitive: false)
        .firstMatch(tail);
    if (labelled != null) candidates.add(labelled.group(1)!);
  }
  final parsed = candidates.map(parseBankAmount).toList();
  if (parsed.any((value) => value == null)) return null;
  final values = parsed.cast<double>().toSet();
  if (values.length != 1) return null;
  final amount = values.single;
  if (amount <= 0 || !amount.isFinite || amount >= 999999999999) return null;
  return ParsedBankSms(
      sender: sender, amount: amount, income: incoming != null);
}

double? parseBankAmount(String raw) {
  var value = normalizeBankText(raw);
  if (value.contains(',') && value.contains('.')) {
    // Both decimal styles: 1,234.500 or 1.234,500.
    if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      value = value.replaceAll(',', '');
    }
  } else if (value.contains(',')) {
    final groups = value.split(',');
    // A single three-digit comma group is ambiguous (1,234): ask the user.
    if (groups.length == 2 && groups.last.length == 3) return null;
    if (groups.length > 2) {
      if (groups.skip(1).any((g) => g.length != 3)) return null;
      value = groups.join();
    } else {
      value = value.replaceAll(',', '.');
    }
  }
  return double.tryParse(value);
}
