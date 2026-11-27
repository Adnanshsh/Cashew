import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:budget/pages/autoTransactionsPageEmail.dart';
import 'package:budget/struct/expense_tools/bank_sms_parser.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/budgetsListPage.dart';
import 'package:budget/pages/objectivesListPage.dart';
import 'package:budget/pages/upcomingOverdueTransactionsPage.dart';
import 'package:budget/pages/creditDebtTransactionsPage.dart';
import 'package:budget/pages/expense_tools/bank_sms_page.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/expense_tools/expense_tools.dart';
import 'package:budget/struct/expense_tools/spending_cycle.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter/material.dart';

typedef PlanTotals = (double, double, double, double, double, Set<String>);

class SpendingPlanEntry extends StatelessWidget {
  const SpendingPlanEntry({super.key});
  @override
  Widget build(BuildContext context) => SpendingPlanPage(
      key: ValueKey(appStateSettings['selectedWalletPk']), compact: true);
}

class SpendingPlanPage extends StatefulWidget {
  const SpendingPlanPage({super.key, this.compact = false});
  final bool compact;
  @override
  State<SpendingPlanPage> createState() => _SpendingPlanState();
}

class _SpendingPlanState extends State<SpendingPlanPage> {
  late final String wallet = appStateSettings['selectedWalletPk'] as String;
  String get key => 'spendingPlan/$wallet';
  Timer? rollover;
  late Set<String> ignored, refunds;
  late int payday;
  late double salary, savings, cap;
  late SpendingCycle cycle;
  late Stream<PlanTotals> rows;
  late final walletName = database.getAllWallets().then((list) => list
      .where((w) => w.walletPk == wallet)
      .map((w) => [w.name, if (w.currency != null) w.currency!.toUpperCase()]
          .join(' · '))
      .join());
  String t(String ar, String en) => expenseText(context, ar, en);
  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  void loadSettings() {
    final config = appStateSettings[key] as Map? ?? {};
    ignored = Set<String>.from(config['ignored'] ?? []);
    refunds = Set<String>.from(config['refunds'] ?? []);
    payday = config['payday'] ?? 1;
    salary = config['salary'] ?? 0.0;
    savings = config['savings'] ?? 0.0;
    cap = config['cap'] ?? 0.0;
    refresh();
  }

  void refresh() {
    cycle = SpendingCycle(DateTime.now(), payday);
    rollover?.cancel();
    rollover = Timer(
        DateTime(cycle.today.year, cycle.today.month, cycle.today.day + 1)
            .difference(DateTime.now()), () {
      if (mounted) setState(refresh);
    });
    rows = database
        .getTransactionsInTimeRangeFromCategories(
            cycle.start,
            DateTime(cycle.next.year, cycle.next.month, cycle.next.day - 1),
            null,
            ['0'],
            false,
            null,
            null,
            null,
            walletPks: [wallet])
        .asyncMap((transactions) async {
      final result = calculate(transactions);
      if (ExpenseTools.supported && mounted) {
        final snapshot = [
          DateTime.now().toIso8601String(),
          result.$4.toStringAsFixed(3),
          await walletName
        ];
        try {
          await HomeWidget.saveWidgetData<String>(
              'dailyPlanSnapshot', snapshot.join('\n'));
          await HomeWidget.updateWidget(name: 'DailyPlanWidgetProvider');
        } on Exception catch (e) {
          debugPrint('Daily plan widget: $e');
        }
      }
      return result;
    });
  }

  @override
  void dispose() {
    rollover?.cancel();
    super.dispose();
  }

  Future<void> configure() async {
    final categories =
        (await database.getAllCategories()).where((c) => c.categoryPk != '0');
    if (!mounted) return;
    final excluded = {...ignored}, returned = {...refunds};
    final form = GlobalKey<FormState>();
    final values = [payday.toDouble(), salary, savings, cap];
    final labels = [
      t('يوم الراتب (1–31)', 'Payday (1–31)'),
      t('دخل الدورة المخطط (0 للدخل المسجل)',
          'Planned income (0 uses recorded income)'),
      t('مبلغ محجوز للادخار', 'Savings reserve'),
      t('سقف يومي اختياري (0 للتلقائي)', 'Optional daily cap (0 for automatic)')
    ];
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: Text(t('إعداد الدورة', 'Cycle settings')),
                content: SingleChildScrollView(
                    child: Form(
                        key: form,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          for (int i = 0; i < values.length; i++)
                            TextFormField(
                                initialValue: values[i]
                                    .toString()
                                    .replaceFirst(RegExp(r'\.0$'), ''),
                                decoration:
                                    InputDecoration(labelText: labels[i]),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) {
                                  final n = double.tryParse(
                                      normalizeBankText(v ?? '').trim());
                                  if (n == null ||
                                      !n.isFinite ||
                                      n < 0 ||
                                      (i == 0 &&
                                          (n < 1 || n > 31 || n != n.floor())))
                                    return t('راجع القيمة', 'Check value');
                                  values[i] = n;
                                  return null;
                                }),
                          ExpansionTile(
                              title: Text(t(
                                  'فئات تُستثنى من الصرف أو تُحسب كاسترداد',
                                  'Excluded spending and refund categories')),
                              children: [
                                for (final c in categories)
                                  StatefulBuilder(builder: (ctx, change) {
                                    final selection =
                                        c.income ? returned : excluded;
                                    return CheckboxListTile(
                                        value: selection.contains(c.categoryPk),
                                        title: Text(c.name),
                                        subtitle: Text(c.income
                                            ? t('استرداد', 'Refund')
                                            : t('استبعاد من الصرف',
                                                'Exclude from spending')),
                                        onChanged: (v) => change(() {
                                              if (v == true) {
                                                selection.add(c.categoryPk);
                                              } else {
                                                selection.remove(c.categoryPk);
                                              }
                                            }));
                                  })
                              ]),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () {
                        if (form.currentState!.validate())
                          Navigator.pop(dialog, true);
                      },
                      child: Text(t('حفظ', 'Save')))
                ]));
    if (saved != true || !mounted) return;
    await updateSettings(
        key,
        {
          'payday': values[0].toInt(),
          'salary': values[1],
          'savings': values[2],
          'cap': values[3],
          'ignored': excluded.toList(),
          'refunds': returned.toList()
        },
        updateGlobalState: false);
    if (!mounted) return;
    setState(() {
      ignored = excluded;
      refunds = returned;
      payday = values[0].toInt();
      salary = values[1];
      savings = values[2];
      cap = values[3];
      refresh();
    });
  }

  PlanTotals calculate(List<Transaction> transactions) {
    double received = 0, before = 0, today = 0, reserved = savings;
    final seen = <String>{}, duplicates = <String>{};
    for (final tx in transactions) {
      if (ignored.contains(tx.categoryFk) ||
          tx.pairedTransactionFk != null ||
          tx.objectiveLoanFk != null ||
          tx.type == TransactionSpecialType.credit ||
          tx.type == TransactionSpecialType.debt) continue;
      final refund = tx.income && refunds.contains(tx.categoryFk);
      final amount = refund ? -tx.amount.abs() : tx.amount.abs();
      if (!tx.paid) {
        if (!tx.income) reserved += amount;
        continue;
      }
      final day = DateUtils.dateOnly(tx.dateCreated);
      if (day.isAfter(cycle.today)) continue;
      if (tx.income && !refund) {
        received += amount;
        continue;
      }
      if (day == cycle.today) {
        today += amount;
      } else {
        before += amount;
      }
      if (refund) continue;
      final name = tx.name.trim().toLowerCase();
      if (name.isNotEmpty && !seen.add('$day/$amount/$name'))
        duplicates.add(
            '${tx.name} · ${amount.toStringAsFixed(3)} · ${day.day}/${day.month}');
    }
    final funds = salary > 0 ? salary : received;
    final available = cycle.availableToday(funds, reserved, before, today, cap);

    final projection = funds -
        reserved -
        before -
        today -
        (before + today) / cycle.elapsed * (cycle.daysLeft - 1);
    return (today, reserved, before, available, projection, duplicates);
  }

  Widget link(String label, Widget page) => ListTile(
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)));

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return summary();
    return Scaffold(
        appBar: AppBar(
            title: Text(t('خطة الصرف اليومي', 'Daily spending plan')),
            actions: [
              IconButton(
                  tooltip: t('إعداد الدورة', 'Cycle settings'),
                  icon: const Icon(Icons.tune),
                  onPressed: configure)
            ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          FutureBuilder<String>(
              future: walletName, builder: (_, s) => Text(s.data ?? '')),
          summary(),
          if (ExpenseTools.supported)
            link(t('قواعد تصنيف إشعارات المصرف', 'Bank notification rules'),
                const AutoTransactionsPageNotifications()),
          if (ExpenseTools.supported)
            link(t('مراجعة رسائل المصرف', 'Review bank messages'),
                const BankSmsPage()),
          link(t('ميزانيات الفئات', 'Category budgets'),
              const BudgetsListPage(enableBackButton: true)),
          link(t('أهداف الادخار', 'Savings goals'),
              const ObjectivesListPage(backButton: true)),
          link(t('الدفعات القادمة', 'Upcoming payments'),
              const UpcomingOverdueTransactions(overdueTransactions: false)),
          link(t('الديون', 'Debts'),
              const CreditDebtTransactions(isCredit: false)),
        ]));
  }

  Widget summary() => StreamBuilder<PlanTotals>(
      stream: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Text(t('تعذر تحميل المعاملات', 'Unable to load transactions'));
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final (today, reserved, before, available, projection, duplicates) =
            snapshot.data!;
        final dailyBase = available + today;
        if (widget.compact)
          return ListTile(
              leading: const Icon(Icons.today_outlined),
              title: Text(
                  t('المتاح اليوم حتى الراتب', 'Available today until payday')),
              subtitle: Text(available.toStringAsFixed(3)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SpendingPlanPage()));
                if (mounted) setState(loadSettings);
              });
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        LinearProgressIndicator(
                            value: dailyBase <= 0
                                ? (today > 0 ? 1.0 : 0.0)
                                : (today / dailyBase)
                                    .clamp(0.0, 1.0)
                                    .toDouble()),
                        Text(t('المتاح اليوم', 'Available today')),
                        Text(available.toStringAsFixed(3),
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                    color: available < 0
                                        ? Theme.of(context).colorScheme.error
                                        : null)),
                        Text(t('باقي ${cycle.daysLeft} يوم للراتب',
                            '${cycle.daysLeft} days to payday')),
                      ]))),
              ListTile(
                  title: Text(t('مصروفات الدورة بعد الاستردادات',
                      'Cycle expenses after refunds')),
                  trailing: Text((before + today).toStringAsFixed(3))),
              ListTile(
                  title: Text(t('صرف اليوم', 'Spent today')),
                  trailing: Text(today.toStringAsFixed(3))),
              ListTile(
                  title: Text(t('محجوز للادخار والدفعات المستحقة',
                      'Reserved for savings and unpaid expenses')),
                  trailing: Text(reserved.toStringAsFixed(3))),
              ListTile(
                  title: Text(t('الرصيد المتوقع قبل الراتب',
                      'Projected balance before payday')),
                  subtitle: Text(t('حسب متوسط صرف الدورة حتى اليوم',
                      'Based on average spending so far')),
                  trailing: Text(projection.toStringAsFixed(3))),
              for (final label in duplicates)
                ListTile(
                    leading: const Icon(Icons.copy),
                    title: Text(t('راجع خصمًا محتمل التكرار',
                        'Review possible duplicate')),
                    subtitle: Text(label)),
            ]);
      });
}
