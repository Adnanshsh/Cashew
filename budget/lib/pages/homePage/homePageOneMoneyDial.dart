import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/transactionsSearchPage.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/categoryIcon.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/pieChart.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class HomePageOneMoneyDial extends StatefulWidget {
  const HomePageOneMoneyDial({super.key});

  @override
  State<HomePageOneMoneyDial> createState() => _HomePageOneMoneyDialState();
}

class _HomePageOneMoneyDialState extends State<HomePageOneMoneyDial> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? selectedWalletPk; // null = كل الحسابات
  bool isExpense = true; // true = المصروفات، false = الدخل

  void _changeMonth(int delta) {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + delta);
    });
  }

  DateTime get _startOfMonth =>
      DateTime(selectedMonth.year, selectedMonth.month, 1);

  DateTime get _endOfMonth =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final allWallets = Provider.of<AllWallets>(context);

    return StreamBuilder<List<TransactionCategory>>(
      stream: database.watchAllCategories(),
      builder: (context, catSnapshot) {
        if (!catSnapshot.hasData) return const SizedBox.shrink();

        // تصفية الفئات حسب النوع (مصروفات أو دخل) واستبعاد فئات التحويل
        final categories = catSnapshot.data!
            .where((c) => c.income == !isExpense)
            .toList();

        return StreamBuilder<List<Transaction>>(
          stream: database.getTransactionsInTimeRangeFromCategories(
            _startOfMonth,
            _endOfMonth,
            null,
            null,
            true,
            null,
            null,
            null,
          ),
          builder: (context, txSnapshot) {
            final transactions = (txSnapshot.data ?? []).where((tx) {
              if (tx.paid == false) return false;
              if (selectedWalletPk != null && tx.walletFk != selectedWalletPk) {
                return false;
              }
              return isExpense ? tx.amount < 0 : tx.amount > 0;
            }).toList();

            // حساب إجمالي كل فئة
            Map<String, double> categoryTotals = {};
            double totalAmount = 0;

            for (var tx in transactions) {
              double converted = tx.amount.abs() *
                  amountRatioToPrimaryCurrencyGivenPk(
                      allWallets, tx.walletFk);
              categoryTotals[tx.categoryFk] =
                  (categoryTotals[tx.categoryFk] ?? 0) + converted;
              totalAmount += converted;
            }

            // تجهيز بيانات الدائرة البيانية (Donut Chart)
            List<PieChartDisplayData> pieData = [];
            for (var cat in categories) {
              double val = categoryTotals[cat.categoryPk] ?? 0;
              if (val > 0) {
                pieData.add(
                  PieChartDisplayData(
                    title: cat.name,
                    percent: totalAmount > 0 ? (val / totalAmount) * 100 : 0,
                    color: HexColor(cat.colour),
                    amount: val,
                  ),
                );
              }
            }

            // تقسيم الفئات حسب توزيع 1Money (4 فوق، 2 يمين، 2 يسار، والباقي تحت)
            final topRow = categories.take(4).toList();
            final rightCol = categories.skip(4).take(2).toList();
            final leftCol = categories.skip(6).take(2).toList();
            final bottomGrid = categories.skip(8).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  // 1. الشريط العلوي: اختيار الحساب والرصيد
                  _buildHeaderAccountBar(context, allWallets),
                  const SizedBox(height: 10),

                  // 2. شريط التنقل بين الأشهر
                  _buildMonthSelector(context),
                  const SizedBox(height: 18),

                  // 3. الصف العلوي (4 فئات)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: topRow
                        .map((cat) => Expanded(
                              child: _buildCategoryNode(
                                context,
                                cat,
                                categoryTotals[cat.categoryPk] ?? 0,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),

                  // 4. المنتصف: (يمين: فئتين) + (وسط: الدائرة) + (يسار: فئتين)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // العمود الأيمن
                      SizedBox(
                        width: 78,
                        child: Column(
                          children: rightCol
                              .map((cat) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildCategoryNode(
                                      context,
                                      cat,
                                      categoryTotals[cat.categoryPk] ?? 0,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),

                      // الدائرة البيانية في المنتصف (الضغط عليها يبدل بين المصروفات والدخل)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              isExpense = !isExpense;
                            });
                          },
                          child: SizedBox(
                            height: 185,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChartWrapper(
                                  data: pieData.isEmpty
                                      ? [
                                          PieChartDisplayData(
                                            title: "",
                                            percent: 100,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant,
                                            amount: 0,
                                          )
                                        ]
                                      : pieData,
                                  isDonut: true,
                                  donutWidth: 16,
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFont(
                                      text: isExpense ? "النفقات" : "الدخل",
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    const SizedBox(height: 4),
                                    TextFont(
                                      text: convertToMoney(
                                          allWallets, totalAmount),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      textColor: isExpense
                                          ? getColor(context, "expenseAmount")
                                          : getColor(context, "incomeAmount"),
                                    ),
                                    const SizedBox(height: 2),
                                    TextFont(
                                      text: "اضغط للتبديل",
                                      fontSize: 10,
                                      textColor: getColor(context, "textLight"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // العمود الأيسر
                      SizedBox(
                        width: 78,
                        child: Column(
                          children: leftCol
                              .map((cat) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildCategoryNode(
                                      context,
                                      cat,
                                      categoryTotals[cat.categoryPk] ?? 0,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 5. باقي الفئات + زر إضافة فئة (+)
                  Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    alignment: WrapAlignment.start,
                    children: [
                      ...bottomGrid.map(
                        (cat) => SizedBox(
                          width: (MediaQuery.of(context).size.width - 64) / 4,
                          child: _buildCategoryNode(
                            context,
                            cat,
                            categoryTotals[cat.categoryPk] ?? 0,
                          ),
                        ),
                      ),
                      // زر + لإضافة فئة جديدة
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 4,
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Tappable(
                              onTap: () {
                                pushRoute(
                                  context,
                                  AddCategoryPage(
                                    routesToPopAfterDelete:
                                        RoutesToPopAfterDelete.None,
                                  ),
                                );
                              },
                              borderRadius: 50,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: getColor(context, "textLight")
                                        .withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: getColor(context, "textLight"),
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// شريط اختيار الحساب والرصيد في الأعلى (مثل 1Money)
  Widget _buildHeaderAccountBar(BuildContext context, AllWallets allWallets) {
    final currentWallet = selectedWalletPk != null
        ? allWallets.indexedByPk[selectedWalletPk]
        : null;

    return StreamBuilder<double?>(
      stream: database.watchTotalOfWallet(
        selectedWalletPk == null ? null : [selectedWalletPk!],
        isPaid: true,
        allWallets: allWallets,
        followCustomPeriodCycle: false,
        cycleSettingsExtension: "",
      ),
      builder: (context, balanceSnapshot) {
        final balance = balanceSnapshot.data ?? 0;

        return Tappable(
          onTap: () {
            // فتح قائمة اختيار الحساب
            _showWalletPickerSheet(context, allWallets);
          },
          borderRadius: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFont(
                      text: currentWallet?.name ?? "كل الحسابات",
                      fontSize: 14,
                      textColor: getColor(context, "textLight"),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: getColor(context, "textLight"),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                TextFont(
                  text: convertToMoney(
                    allWallets,
                    balance,
                    currencyKey: currentWallet?.currency,
                  ),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// شريط التنقل بين الأشهر (< نوفمبر 2026 >)
  Widget _buildMonthSelector(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', context.locale.toString())
        .format(selectedMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFont(
                text: monthLabel,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
        ),
      ],
    );
  }

  /// عنصر الفئة الواحدة (الاسم + الأيقونة الدائرية + المبلغ)
  Widget _buildCategoryNode(
    BuildContext context,
    TransactionCategory category,
    double spentAmount,
  ) {
    final allWallets = Provider.of<AllWallets>(context, listen: false);
    final catColor = HexColor(category.colour);

    return GestureDetector(
      // الضغط المباشر -> فتح الإدخال الفوري (1Money Style)
      onTap: () {
        HapticFeedback.lightImpact();
        openBottomSheet(
          context,
          fullSnap: true,
          AddTransactionPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
            selectedCategory: category,
            selectedWallet: selectedWalletPk != null
                ? allWallets.indexedByPk[selectedWalletPk]
                : null,
            selectedIncome: !isExpense,
          ),
        );
      },
      // الضغط المطول -> عرض معاملات هذه الفئة
      onLongPress: () {
        HapticFeedback.mediumImpact();
        pushRoute(
          context,
          TransactionsSearchPage(
            initialFilters: SearchFilters(
              categoryPks: [category.categoryPk],
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFont(
            text: category.name,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: catColor.withOpacity(0.16),
            ),
            child: Center(
              child: CategoryIcon(
                categoryPk: category.categoryPk,
                size: 26,
                category: category,
                canEditByLongPress: false,
                noBackground: true,
              ),
            ),
          ),
          const SizedBox(height: 5),
          TextFont(
            text: convertToMoney(allWallets, spentAmount, decimals: 0),
            fontSize: 12,
            fontWeight: spentAmount > 0 ? FontWeight.bold : FontWeight.normal,
            textColor: spentAmount > 0
                ? catColor
                : getColor(context, "textLight"),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  /// نافذة اختيار الحساب السريعة
  void _showWalletPickerSheet(BuildContext context, AllWallets allWallets) {
    openBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextFont(
              text: "اختر الحساب",
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded),
              title: const TextFont(text: "كل الحسابات", fontSize: 16),
              trailing: selectedWalletPk == null
                  ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => selectedWalletPk = null);
                Navigator.pop(context);
              },
            ),
            ...allWallets.list.map((wallet) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: HexColor(wallet.colour).withOpacity(0.2),
                    child: Icon(
                      Icons.credit_card_rounded,
                      color: HexColor(wallet.colour),
                    ),
                  ),
                  title: TextFont(text: wallet.name, fontSize: 16),
                  trailing: selectedWalletPk == wallet.walletPk
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() => selectedWalletPk = wallet.walletPk);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
