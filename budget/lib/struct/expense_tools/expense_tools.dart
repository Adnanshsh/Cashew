import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/expense_tools/bank_sms_parser.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/expense_tools/bank_sms_page.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

String expenseText(BuildContext context, String arabic, String english) =>
    context.locale.languageCode == 'ar' ? arabic : english;

class ExpenseTools {
  static const channel = MethodChannel('cashew/expense_tools');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool _ready = false;
  static bool _opening = false;
  static bool _quickPending = false;
  static bool _bankPending = false;
  static final _bankCaptures = <String, String>{};
  static String? _activeCapture;
  static bool get quickDebitEnabled =>
      appStateSettings['bankSmsQuickDebit'] == true;

  static Future<void> configureBankSms() async {
    if (!supported) return;
    await channel.invokeMethod('configureSms', {
      'enabled': appStateSettings['bankSmsEnabled'] == true,
      'quickDebit': quickDebitEnabled,
    });
  }

  static Future<void> _consumeLaunch() async {
    final launch =
        await channel.invokeMapMethod<String, dynamic>('consumeLaunch');
    _quickPending = _quickPending || launch?['quick'] == true;
    _bankPending = _bankPending || launch?['bank'] == true;
    final captures = launch?['captures'];
    if (captures is Map) {
      for (final entry in captures.entries) {
        final id = entry.key;
        final mode = entry.value;
        if (id is String && mode is String && id != _activeCapture) {
          _bankCaptures[id] = mode;
        }
      }
    }
  }

  static final inboxRevision = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (_ready) {
        await _consumeLaunch();
        await _openPending();
      }
    });
    await configureBankSms();
  }

  static Future<void> onReady() async {
    if (!supported) return;
    _ready = true;
    await onResume();
  }

  static Future<void> onResume() async {
    if (!supported || !_ready) return;
    await _consumeLaunch();
    final opened = _openPending();
    await recordMatchingSms();
    inboxRevision.value++;
    await opened;
  }

  static Future<void> _openPending() async {
    final context = navigatorKey.currentContext;
    if (!_ready || _opening || context == null) return;
    if (_bankCaptures.isNotEmpty) {
      final id = _bankCaptures.keys.first;
      final mode = _bankCaptures.remove(id)!;
      _opening = true;
      _activeCapture = id;
      try {
        await _openBankCapture(context, id, mode);
      } finally {
        // A notification tap may reopen a previously dismissed picker.
        _activeCapture = null;
        _opening = false;
      }
    } else if (_quickPending) {
      _quickPending = false;
      await quickEntry(context);
    } else if (_bankPending) {
      _bankPending = false;
      _opening = true;
      try {
        await pushRoute(context, const BankSmsPage());
      } finally {
        _opening = false;
      }
    } else {
      return;
    }
    await _openPending();
  }

  static Future<void> _openBankCapture(
      BuildContext context, String id, String mode) async {
    if (!quickDebitEnabled) return;
    final matches = (await pendingSms()).where((row) => row.id == id);
    if (matches.isEmpty || !context.mounted) return;
    final message = matches.first;
    final existing = await (database.select(database.transactions)
          ..where((t) => t.transactionPk.equals(message.transactionPk)))
        .getSingleOrNull();
    if (existing != null) {
      await dismissSms(id);
      return;
    }
    final parsed = parseBankSmsQuickDebit(message.sender, message.body);
    if (!context.mounted) return;
    if (parsed == null) {
      if (mode == 'manual') await pushRoute(context, const BankSmsPage());
      return;
    }

    final wallets = (await database.getAllWallets())
        .where((wallet) => wallet.currency?.toUpperCase() == 'LYD')
        .toList();
    if (!context.mounted) return;
    final walletKey =
        (appStateSettings['bankSmsWallets'] as Map?)?[message.sender];
    final linked = wallets.where((wallet) => wallet.walletPk == walletKey);
    var floating = false;
    try {
      if (mode == 'floating') {
        await channel.invokeMethod('quickWindow', {'enabled': true});
        floating = true;
      }
      if (!context.mounted) return;
      final wallet = linked.isNotEmpty
          ? linked.first
          : await showDialog<TransactionWallet>(
              context: context,
              useRootNavigator: false,
              builder: (dialogContext) => SimpleDialog(
                title: Text(expenseText(
                    context, 'اختر حساب الخصم', 'Choose the account charged')),
                children: [
                  if (wallets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(expenseText(
                          context,
                          'لا يوجد حساب بالدينار الليبي.',
                          'No Libyan dinar account is available.')),
                    ),
                  for (final account in wallets)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, account),
                      child: Text(account.name),
                    ),
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(expenseText(context, 'لاحقًا', 'Later')),
                  ),
                ],
              ),
            );
      if (wallet == null || !context.mounted) return;
      final selection = await selectCategorySequence(
        context,
        selectedCategory: null,
        setSelectedCategory: (_) {},
        selectedSubCategory: null,
        setSelectedSubCategory: (_) {},
        selectedIncomeInitial: false,
        allowDirectionOverride: false,
        subtitle: '${parsed.amount.toStringAsFixed(3)} · ${wallet.name}',
        allowReorder: false,
      );
      if (selection.main == null || selection.main!.income || !context.mounted)
        return;
      await pushRoute(
        context,
        AddTransactionPage(
          transactionPkOverride: message.transactionPk,
          selectedWallet: wallet,
          selectedAmount: parsed.amount,
          selectedIncome: false,
          selectedCategory: selection.main,
          selectedSubCategory: selection.sub,
          selectedDate: message.date,
          selectedTitle: bankSmsSenders[message.sender],
          startInitialAddTransactionSequence: false,
          onTransactionSaved: (_) => dismissSms(id),
          routesToPopAfterDelete: RoutesToPopAfterDelete.None,
        ),
      );
    } finally {
      if (floating) await channel.invokeMethod('finishQuickWindow');
    }
  }

  static Future<void> quickEntry(BuildContext context) async {
    if (_opening) return;
    _opening = true;
    try {
      if (supported)
        await channel.invokeMethod('quickWindow', {'enabled': true});
      await pushRoute(
          context,
          AddTransactionPage(
            selectedIncome: false,
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
          ));
    } finally {
      _opening = false;
      if (supported) await channel.invokeMethod('finishQuickWindow');
    }
  }

  static Future<bool> showBubble({bool requestPermission = true}) async {
    if (!supported) return false;
    return await channel.invokeMethod<bool>(
            'showBubble', {'requestPermission': requestPermission}) ??
        false;
  }

  static Future<List<BankSmsMessage>> pendingSms() async {
    if (!supported) return [];
    final text = await channel.invokeMethod<String>('pendingSms') ?? '[]';
    return (jsonDecode(text) as List)
        .map((row) => BankSmsMessage.fromJson(Map<String, dynamic>.from(row)))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> recordMatchingSms() async {
    final enabledSince = appStateSettings['bankSmsAutoSince'];
    if (!supported ||
        appStateSettings['bankSmsEnabled'] != true ||
        enabledSince is! int) return;
    final rules = await database.getAllScannerTemplates();
    final mappings = appStateSettings['bankSmsWallets'] as Map? ?? {};
    for (final message in await pendingSms()) {
      if (message.date.millisecondsSinceEpoch < enabledSince) continue;
      final parsed = parseBankSms(message.sender, message.body);
      if (quickDebitEnabled && parsed?.income == false) continue;
      final walletKey = mappings[message.sender];
      if (parsed == null || walletKey is! String) continue;
      final matches = rules
          .where((r) =>
              r.contains.trim().isNotEmpty &&
              message.body.contains(r.contains) &&
              (r.walletFk == walletKey || r.walletFk == '-1'))
          .toList();
      if (matches.length != 1) continue;
      final rule = matches.single;
      final category =
          await database.getCategoryInstanceOrNull(rule.defaultCategoryFk);
      final wallet = await database.getWalletInstanceOrNull(walletKey);
      if (category == null ||
          category.categoryPk == '0' ||
          category.income != parsed.income ||
          wallet?.currency?.toUpperCase() != 'LYD') continue;
      final recorded = await database.transaction(() async {
        final existing = await (database.select(database.transactions)
              ..where((t) => t.transactionPk.equals(message.transactionPk)))
            .getSingleOrNull();
        if (existing != null) return true;
        return await database.createOrUpdateTransaction(
                Transaction(
                    transactionPk: message.transactionPk,
                    name: rule.templateName,
                    amount: parsed.income ? parsed.amount : -parsed.amount,
                    note: '',
                    categoryFk: category.categoryPk,
                    walletFk: walletKey,
                    dateCreated: message.date,
                    income: parsed.income,
                    paid: true,
                    skipPaid: false),
                updateSharedEntry: false) !=
            null;
      });
      if (recorded) await dismissSms(message.id);
    }
  }

  static Future<void> dismissSms(String id) async {
    await channel.invokeMethod('dismissSms', {
      'ids': [id]
    });
    inboxRevision.value++;
  }
}

class BankSmsMessage {
  const BankSmsMessage(
      {required this.id,
      required this.sender,
      required this.body,
      required this.date});
  final String id;
  final String sender;
  final String body;
  final DateTime date;
  String get transactionPk => 'bank-sms-$id';
  factory BankSmsMessage.fromJson(Map<String, dynamic> json) => BankSmsMessage(
        id: json['id'] as String,
        sender: json['sender'] as String,
        body: json['body'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(
            (json['timestamp'] as num).toInt()),
      );
}
