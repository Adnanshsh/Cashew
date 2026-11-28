import 'package:drift/drift.dart' hide Column;
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/autoTransactionsPageEmail.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/expense_tools/bank_sms_paste_page.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/expense_tools/bank_sms_parser.dart';
import 'package:budget/struct/expense_tools/expense_tools.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/notificationsSettings.dart'
    show checkNotificationsPermissionAndroid;
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/util/onAppResume.dart';
import 'package:flutter/material.dart';

class BankSmsPage extends StatefulWidget {
  const BankSmsPage({super.key});
  @override
  State<BankSmsPage> createState() => _BankSmsPageState();
}

class _BankSmsPageState extends State<BankSmsPage> {
  List<TransactionWallet> _wallets = [];
  List<BankSmsMessage> _messages = [];
  bool _loading = true;
  bool _busy = false;
  bool _permission = false;
  bool _overlayPermission = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallets = await database.getAllWallets();
      final permission =
          await ExpenseTools.channel.invokeMethod<bool>('smsPermission') ??
              false;
      final overlay =
          await ExpenseTools.channel.invokeMethod<bool>('overlayPermission') ??
              false;
      await ExpenseTools.recordMatchingSms();
      final messages = await ExpenseTools.pendingSms();
      final pending = <BankSmsMessage>[];
      for (final message in messages) {
        final existing = await (database.select(database.transactions)
              ..where((t) => t.transactionPk.equals(message.transactionPk)))
            .getSingleOrNull();
        if (existing != null) {
          await ExpenseTools.dismissSms(message.id);
        } else {
          pending.add(message);
        }
      }
      if (mounted)
        setState(() {
          _wallets = wallets;
          _messages = pending;
          _permission = permission;
          _overlayPermission = overlay;
          _loading = false;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = expenseText(context, 'تعذر تحميل الرسائل. حاول مرة أخرى.',
              'Could not load messages. Please retry.');
        });
    }
  }

  Map<String, dynamic> get _mappings =>
      Map<String, dynamic>.from(appStateSettings['bankSmsWallets'] ?? {});

  String? _walletFor(String sender) {
    final explicit = _mappings[sender];
    if (_wallets.any((w) => w.walletPk == explicit)) return explicit as String;
    final bank = normalizeBankText(bankSmsSenders[sender] ?? '');
    final matches = _wallets
        .where((w) => normalizeBankText(w.name).contains(bank))
        .toList();
    return matches.length == 1 ? matches.single.walletPk : null;
  }

  Future<void> _review(BankSmsMessage message) async {
    if (_busy) return;
    final walletPk = _walletFor(message.sender);
    if (walletPk == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(expenseText(
              context,
              'اربط المرسل بحساب أولًا من الأعلى.',
              'Choose an account for this sender first.'))));
      return;
    }
    final parsed = parseBankSms(message.sender, message.body);
    setState(() => _busy = true);
    try {
      // The normal transaction editor requires a category and user confirmation.
      // Raw SMS text remains in the private inbox; it is not copied to sync notes.
      await pushRoute(
          context,
          AddTransactionPage(
            transactionPkOverride: message.transactionPk,
            selectedWallet: _wallets.firstWhere((w) => w.walletPk == walletPk),
            selectedAmount: parsed?.amount,
            selectedIncome: parsed?.income,
            selectedDate: message.date,
            selectedTitle:
                '${bankSmsSenders[message.sender]} • ${message.sender}',
            selectedNotes: expenseText(
                context,
                'من رسالة مصرفية (${message.sender})',
                'From a bank message (${message.sender})'),
            onTransactionSaved: (_) async {
              await ExpenseTools.dismissSms(message.id);
            },
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
          ));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnAppResume(
        onAppResume: _load,
        child: Scaffold(
          appBar: AppBar(
              title:
                  Text(expenseText(context, 'رسائل البنوك', 'Bank messages')),
              actions: [
                IconButton(
                    tooltip: expenseText(
                        context, 'الصق رسالة البنك', 'Paste a bank message'),
                    onPressed: () =>
                        pushRoute(context, const BankSmsPastePage()),
                    icon: const Icon(Icons.content_paste)),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
              ]),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(expenseText(
                        context,
                        'اقرأ رسائل الخصم والإضافة الجديدة من المرسلين المحددين فقط. تظهر الرسائل للمراجعة ما لم تفعّل قواعد التسجيل التلقائي. فعّل الإذن ثم اربط كل مرسل بالحساب الصحيح.',
                        'Receive new debit and credit messages from these senders only. Messages are reviewed unless automatic rules are enabled. Enable permission and link each sender to its account.')),
                    SwitchListTile(
                      title: Text(expenseText(
                          context,
                          'قراءة الرسائل المصرفية الجديدة',
                          'Receive new bank messages')),
                      subtitle: Text(expenseText(
                          context,
                          'المعالجة على الهاتف؛ لا يتم قراءة سجل الرسائل القديم.',
                          'Processed on this phone; existing SMS history is not read.')),
                      value: appStateSettings['bankSmsEnabled'] == true &&
                          _permission,
                      onChanged: (enabled) async {
                        if (enabled) {
                          enabled = await ExpenseTools.channel
                                  .invokeMethod<bool>('requestSmsPermission') ??
                              false;
                          if (!enabled && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(expenseText(
                                    context,
                                    'لم يُمنح إذن الرسائل. فعّله من إعدادات أذونات التطبيق إذا كان متاحًا.',
                                    'SMS permission was not granted. Check the app permissions in Android settings.'))));
                          }
                        }
                        await updateSettings('bankSmsEnabled', enabled,
                            updateGlobalState: false);
                        await ExpenseTools.configureBankSms();
                        if (mounted) setState(() => _permission = enabled);
                      },
                    ),
                    SwitchListTile(
                      title: Text(expenseText(context, 'اختيار قسم الخصم فورًا',
                          'Choose a category when debited')),
                      subtitle: Text(expenseText(
                          context,
                          'للخصومات الواضحة فقط. لو الهاتف مقفول أو ما سمحش بعرض النافذة، افتحها من الإشعار.',
                          'For clear debits only. If the window is blocked or the phone is locked, open the prompt from the notification.')),
                      value: ExpenseTools.quickDebitEnabled,
                      onChanged: !_permission
                          ? null
                          : (enabled) async {
                              await updateSettings('bankSmsQuickDebit', enabled,
                                  updateGlobalState: false);
                              await ExpenseTools.configureBankSms();
                              if (!mounted) return;
                              setState(() {});
                              if (!enabled) return;
                              await checkNotificationsPermissionAndroid();
                              if (mounted && !_overlayPermission) {
                                await ExpenseTools.channel
                                    .invokeMethod('requestOverlayPermission');
                              }
                            },
                    ),
                    if (ExpenseTools.quickDebitEnabled && !_overlayPermission)
                      ListTile(
                        title: Text(expenseText(
                            context,
                            'السماح بالظهور فوق التطبيقات',
                            'Allow display over other apps')),
                        onTap: () => ExpenseTools.channel
                            .invokeMethod('requestOverlayPermission'),
                      ),
                    SwitchListTile(
                        title: Text(expenseText(
                            context,
                            'تسجيل الرسائل المطابقة تلقائيًا',
                            'Automatically record matching messages')),
                        subtitle: Text(expenseText(
                            context,
                            'عند فتح التطبيق تُسجّل الرسائل المطابقة لقالب واحد. عند تفعيل الاختيار الفوري، لا تُسجّل الخصومات تلقائيًا.',
                            'On opening the app, messages matching one template are recorded. Debits are not auto-recorded when instant category selection is enabled.')),
                        value: appStateSettings['bankSmsAutoSince'] is int,
                        onChanged: (v) async {
                          await updateSettings('bankSmsAutoSince',
                              v ? DateTime.now().millisecondsSinceEpoch : null,
                              updateGlobalState: false);
                          if (mounted) setState(() {});
                        }),
                    ListTile(
                        title: Text(expenseText(context, 'قوالب التصنيف',
                            'Classification templates')),
                        onTap: () => pushRoute(context,
                            const AutoTransactionsPageNotifications())),
                    for (final entry in bankSmsSenders.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _walletFor(entry.key),
                          decoration: InputDecoration(
                              labelText: '${entry.key} — ${entry.value}',
                              border: const OutlineInputBorder()),
                          hint: Text(expenseText(
                              context, 'اختر الحساب', 'Select account')),
                          items: _wallets
                              .map((w) => DropdownMenuItem(
                                  value: w.walletPk, child: Text(w.name)))
                              .toList(),
                          onChanged: (value) async {
                            await updateSettings('bankSmsWallets',
                                {..._mappings, entry.key: value},
                                updateGlobalState: false);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    Text(
                        expenseText(
                            context,
                            'بانتظار المراجعة (${_messages.length})',
                            'Awaiting review (${_messages.length})'),
                        style: Theme.of(context).textTheme.titleMedium),
                    if (_messages.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(expenseText(
                              context,
                              'ستظهر هنا الرسائل الجديدة بعد تفعيل الإذن.',
                              'New bank messages will appear here after enabling permission.'))),
                    for (final message in _messages) _messageCard(message),
                  ],
                ),
        ),
      );

  Widget _messageCard(BankSmsMessage message) {
    final parsed = parseBankSms(message.sender, message.body);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${bankSmsSenders[message.sender]} — ${message.sender}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                  '${message.date.year}/${message.date.month}/${message.date.day} ${message.date.hour.toString().padLeft(2, '0')}:${message.date.minute.toString().padLeft(2, '0')}'),
              const SizedBox(height: 8),
              Text(parsed == null
                  ? expenseText(
                      context,
                      'راجع النص وحدد المبلغ ونوع المعاملة يدويًا.',
                      'Review the text and enter the amount and direction manually.')
                  : '${parsed.income ? '+' : '-'}${parsed.amount.toStringAsFixed(3)} د.ل'),
              ExpansionTile(
                  title:
                      Text(expenseText(context, 'نص الرسالة', 'Message text')),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: SelectableText(message.body))
                  ]),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await ExpenseTools.dismissSms(message.id);
                            await _load();
                          },
                    child: Text(expenseText(context, 'تجاهل', 'Dismiss'))),
                FilledButton(
                    onPressed: _busy ? null : () => _review(message),
                    child: Text(expenseText(
                        context, 'مراجعة وتسجيل', 'Review & record'))),
              ]),
            ])));
  }
}
