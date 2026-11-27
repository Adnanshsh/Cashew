import 'dart:convert';
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
  static final inboxRevision = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'quickEntry') _quickPending = true;
      if (call.method == 'bankReview') _bankPending = true;
      await _openPending();
    });
    await channel.invokeMethod('configureSms',
        {'enabled': appStateSettings['bankSmsEnabled'] == true});
  }

  static Future<void> onReady() async {
    if (!supported) return;
    _ready = true;
    await onResume();
  }

  static Future<void> onResume() async {
    if (!supported || !_ready) return;
    final launch =
        await channel.invokeMapMethod<String, dynamic>('consumeLaunch');
    _quickPending = _quickPending || launch?['quick'] == true;
    _bankPending = _bankPending || launch?['bank'] == true;
    await recordMatchingSms();
    inboxRevision.value++;
    await _openPending();
  }

  static Future<void> _openPending() async {
    final context = navigatorKey.currentContext;
    if (!_ready || _opening || context == null) return;
    if (_quickPending) {
      _quickPending = false;
      // Consume native launch extras too, preventing another open on resume.
      await channel.invokeMethod('consumeLaunch');
      await quickEntry(context);
    } else if (_bankPending) {
      _bankPending = false;
      await channel.invokeMethod('consumeLaunch');
      _opening = true;
      try {
        await pushRoute(context, const BankSmsPage());
      } finally {
        _opening = false;
      }
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
        return await database.createOrUpdateTransaction(Transaction(
                transactionPk: message.transactionPk,
                name: rule.templateName,
                amount: parsed.income ? parsed.amount : -parsed.amount,
                note: '',
                categoryFk: category.categoryPk,
                walletFk: walletKey,
                dateCreated: message.date,
                income: parsed.income,
                paid: true,
                skipPaid: false)) !=
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
