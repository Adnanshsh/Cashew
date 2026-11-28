import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart' show pushRoute;
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/expense_tools/bank_sms_parser.dart';
import 'package:budget/struct/expense_tools/expense_tools.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/struct/expense_tools/pasted_bank_transactions.dart';
import 'package:flutter/material.dart';

/// This entry point only receives text the user pastes into the form. It
/// never contacts the Android inbox, requests permission or stores raw SMS.
class BankSmsPastePage extends StatefulWidget {
  const BankSmsPastePage({super.key});

  @override
  State<BankSmsPastePage> createState() => _BankSmsPastePageState();
}

class _BankSmsPastePageState extends State<BankSmsPastePage> {
  final _message = TextEditingController();
  final _wallets = database.getAllWallets().then((wallets) =>
      wallets.where((w) => w.currency?.toUpperCase() == 'LYD').toList());
  DateTime _date = DateTime.now();
  String? _walletKey, _error;
  bool _busy = false;

  String t(String ar, String en) => expenseText(context, ar, en);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(_date),
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _review(TransactionWallet wallet) async {
    if (_busy) return;
    final message = _message.text;
    final parsed = parsePastedBankSms(message);
    if (parsed == null) {
      setState(() => _error = t(
          'ما قدرناش نحدد مبلغًا واحدًا بالدينار الليبي ونوع العملية. راجع الرسالة، أو أضف العملية يدويًا.',
          'Could not identify a single LYD amount and transaction direction. Check the message, or add the transaction manually.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signed = parsed.income ? parsed.amount : -parsed.amount;
      final duplicate = await findSimilarBankTransaction(
          database, wallet.walletPk, _date, parsed);
      final rules = (await database.getAllScannerTemplates())
          .where((rule) =>
              !rule.ignore &&
              rule.contains.trim().isNotEmpty &&
              normalizeBankText(message).toLowerCase().contains(
                    normalizeBankText(rule.contains).trim().toLowerCase(),
                  ) &&
              (rule.walletFk == wallet.walletPk || rule.walletFk == '-1'))
          .toList();
      TransactionCategory? category;
      if (rules.length == 1) {
        final suggested = await database
            .getCategoryInstanceOrNull(rules.single.defaultCategoryFk);
        if (suggested?.income == parsed.income &&
            suggested?.categoryPk != '0') {
          category = suggested;
        }
      }
      if (!mounted) return;
      if (duplicate != null) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(t('عملية مشابهة مسجّلة', 'Possible duplicate')),
            content: Text(t(
                'في عملية بنفس المبلغ والنوع والحساب في نفس اليوم. واصل فقط لو هذي عملية ثانية.',
                'A transaction with the same amount, direction and account already exists on this date. Continue only if this is a different transaction.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(t('رجوع', 'Go back')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(t('راجع كعملية جديدة', 'Review as new')),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }

      var saved = false;
      await pushRoute(
        context,
        AddTransactionPage(
          selectedWallet: wallet,
          selectedAmount: signed,
          selectedIncome: parsed.income,
          selectedCategory: category,
          selectedDate: _date,
          selectedTitle: category == null ? null : rules.single.templateName,
          startInitialAddTransactionSequence: false,
          routesToPopAfterDelete: RoutesToPopAfterDelete.None,
          onTransactionSaved: (_) async {
            saved = true;
            if (mounted) _message.clear();
          },
        ),
      );
      if (mounted && saved) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = t('تعذّرت المراجعة. جرّب من جديد.',
            'Could not open the review. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(t('الصق رسالة البنك', 'Paste a bank message'))),
        body: FutureBuilder<List<TransactionWallet>>(
          future: _wallets,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text(
                      t('تعذّر تحميل الحسابات', 'Unable to load accounts')));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final wallets = snapshot.data!;
            if (wallets.isEmpty) {
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t('أضف حسابًا بالدينار الليبي أولًا.',
                    'Add a Libyan dinar account first.')),
              ));
            }
            final preferred =
                _walletKey ?? appStateSettings['selectedWalletPk'];
            final wallet = wallets.firstWhere((w) => w.walletPk == preferred,
                orElse: () => wallets.first);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t(
                    'الصق إشعار شراء أو إيداع بالدينار الليبي. نص الرسالة يبقى مؤقتًا في هذه الشاشة، وما ينحفظش مع المعاملة. لا تلصق رمز تحقق.',
                    'Paste a purchase or deposit notification in LYD. The text stays temporarily on this screen and is not saved with the transaction. Do not paste a verification code.')),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('bank-message-text'),
                  controller: _message,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 4000,
                  decoration: InputDecoration(
                      labelText: t('نص رسالة البنك', 'Bank message text'),
                      border: const OutlineInputBorder()),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                DropdownButtonFormField<String>(
                  value: wallet.walletPk,
                  decoration:
                      InputDecoration(labelText: t('الحساب', 'Account')),
                  items: wallets
                      .map((w) => DropdownMenuItem(
                          value: w.walletPk, child: Text(w.name)))
                      .toList(),
                  onChanged:
                      _busy ? null : (v) => setState(() => _walletKey = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(t('تاريخ العملية', 'Transaction date')),
                  subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
                  onTap: _busy ? null : _pickDate,
                ),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('bank-message-review'),
                  onPressed: _busy ? null : () => _review(wallet),
                  child: Text(t('راجع قبل الحفظ', 'Review before saving')),
                ),
              ],
            );
          },
        ),
      );
}
