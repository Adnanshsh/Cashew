import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/colors.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/widgets/openPopup.dart';

class OneMoneyQuickEntryPage extends StatefulWidget {
  const OneMoneyQuickEntryPage({Key? key}) : super(key: key);

  @override
  State<OneMoneyQuickEntryPage> createState() => _OneMoneyQuickEntryPageState();
}

class _OneMoneyQuickEntryPageState extends State<OneMoneyQuickEntryPage> {
  String? selectedWalletPk;
  bool showIncome = false;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  final List<String> _arabicMonths = [
    "يناير",
    "فبراير",
    "مارس",
    "أبريل",
    "مايو",
    "يونيو",
    "يوليو",
    "أغسطس",
    "سبتمبر",
    "أكتوبر",
    "نوفمبر",
    "ديسمبر",
  ];

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF4CAF50);
    return HexColor(hexString);
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  double _evalMulDiv(String s) {
    if (s.isEmpty) return 0;
    List<String> mulParts = s.split('*');
    double total = 1;
    for (var m in mulParts) {
      List<String> divParts = m.split('/');
      double dTotal = double.tryParse(divParts[0]) ?? 0;
      for (int i = 1; i < divParts.length; i++) {
        double divisor = double.tryParse(divParts[i]) ?? 1;
        if (divisor != 0) dTotal /= divisor;
      }
      total *= dTotal;
    }
    return total;
  }

  void _open1MoneyCalculatorSheet(
    BuildContext context,
    TransactionCategory category,
    List<TransactionWallet> wallets,
    String initialWalletPk,
  ) {
    String expression = "0";
    String currentWalletPk = initialWalletPk;
    final catColor = _parseColor(category.colour);
    final TextEditingController noteController = TextEditingController();

    double evaluateExpression(String exp) {
      try {
        String clean = exp.replaceAll('×', '*').replaceAll('÷', '/');
        if (clean.endsWith('+') ||
            clean.endsWith('-') ||
            clean.endsWith('*') ||
            clean.endsWith('/')) {
          clean = clean.substring(0, clean.length - 1);
        }
        List<String> addParts = clean.split('+');
        double sum = 0;
        for (var part in addParts) {
          List<String> subParts = part.split('-');
          double subTotal = _evalMulDiv(subParts[0]);
          for (int i = 1; i < subParts.length; i++) {
            subTotal -= _evalMulDiv(subParts[i]);
          }
          sum += subTotal;
        }
        return sum;
      } catch (_) {
        return double.tryParse(exp) ?? 0;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onKey(String key) {
              setSheetState(() {
                if (key == "C") {
                  expression = "0";
                } else if (key == "⌫") {
                  expression = expression.length > 1
                      ? expression.substring(0, expression.length - 1)
                      : "0";
                } else if (key == "=") {
                  double res = evaluateExpression(expression);
                  expression = _formatAmount(res);
                } else if (["+", "-", "×", "÷"].contains(key)) {
                  if (expression.isNotEmpty &&
                      !["+", "-", "×", "÷"]
                          .contains(expression[expression.length - 1])) {
                    expression += key;
                  }
                } else if (key == ".") {
                  expression += ".";
                } else {
                  expression = (expression == "0") ? key : expression + key;
                }
              });
            }

            final currentWallet = wallets.firstWhere(
              (w) => w.walletPk == currentWalletPk,
              orElse: () => wallets.first,
            );

            final bool hasOperator = expression.contains('+') ||
                expression.contains('-') ||
                expression.contains('×') ||
                expression.contains('÷');

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (wallets.length > 1) {
                              int nextIdx =
                                  (wallets.indexOf(currentWallet) + 1) %
                                      wallets.length;
                              setSheetState(() {
                                currentWalletPk = wallets[nextIdx].walletPk;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  currentWallet.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward,
                              color: Colors.white70, size: 18),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  "assets/categories/${category.iconName ?? 'cash-bill-dollar.png'}",
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    color: catColor.withOpacity(0.12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category.income ? "إضافة دخل" : "إضافة مصروف",
                          style: TextStyle(
                              color: catColor, fontWeight: FontWeight.w600),
                        ),
                        Expanded(
                          child: Text(
                            "$expression ل.د",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        hintText: "ملاحظة... (اضغط لإضافة تفاصيل)",
                        prefixIcon: const Icon(Icons.notes, size: 20),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  SizedBox(
                    height: 245,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            childAspectRatio: 1.55,
                            children: [
                              "7",
                              "8",
                              "9",
                              "4",
                              "5",
                              "6",
                              "1",
                              "2",
                              "3",
                              ".",
                              "0",
                              "C"
                            ].map((k) {
                              return InkWell(
                                onTap: () => onKey(k),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey.withOpacity(0.1),
                                        width: 0.5),
                                  ),
                                  child: Text(
                                    k,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              for (var op in ["⌫", "÷", "×", "-", "+"])
                                Expanded(
                                  child: InkWell(
                                    onTap: () => onKey(op),
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        border: Border.all(
                                            color: Colors.grey.withOpacity(0.1),
                                            width: 0.5),
                                      ),
                                      child: Text(
                                        op,
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: catColor),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () async {
                                    if (hasOperator) {
                                      onKey("=");
                                      return;
                                    }
                                    double finalAmount =
                                        evaluateExpression(expression);
                                    if (finalAmount <= 0) return;

                                    await database.createOrUpdateTransaction(
                                      insert: true,
                                      Transaction(
                                        transactionPk: "-1",
                                        name: noteController.text.trim(),
                                        amount: category.income
                                            ? finalAmount
                                            : -finalAmount,
                                        note: "",
                                        categoryFk: category.categoryPk,
                                        walletFk: currentWalletPk,
                                        dateCreated: DateTime.now(),
                                        income: category.income,
                                        paid: true,
                                        skipPaid: false,
                                      ),
                                    );
                                    if (mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    color: catColor,
                                    child: Icon(
                                      hasOperator
                                          ? Icons.drag_handle
                                          : Icons.check,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCell(
    BuildContext context,
    TransactionCategory cat,
    double spent,
    List<TransactionWallet> wallets,
  ) {
    final catColor = _parseColor(cat.colour);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (wallets.isNotEmpty) {
          _open1MoneyCalculatorSheet(
            context,
            cat,
            wallets,
            selectedWalletPk ?? wallets.first.walletPk,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              "0 ل.د",
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 6),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: spent > 0 ? catColor : catColor.withOpacity(0.14),
              ),
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                "assets/categories/${cat.iconName ?? 'cash-bill-dollar.png'}",
                color: spent > 0 ? Colors.white : catColor,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${_formatAmount(spent)} ل.د",
              style: TextStyle(
                fontSize: 12,
                fontWeight: spent > 0 ? FontWeight.bold : FontWeight.w500,
                color: spent > 0 ? catColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryCell(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        pushRoute(
          context,
          const AddCategoryPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1.3),
              ),
              child: Icon(Icons.add, color: Colors.grey.shade600, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
    final monthLabel =
        "${_arabicMonths[selectedMonth.month - 1]} ${selectedMonth.year}";

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<TransactionWallet>>(
          stream:
              database.getAllPinnedWallets(HomePageWidgetDisplay.WalletList).$1,
          builder: (context, walletSnap) {
            final wallets = walletSnap.data ?? [];

            return StreamBuilder<List<TransactionCategory>>(
              stream: database.watchAllCategories(),
              builder: (context, catSnap) {
                final allCategories = catSnap.data ?? [];
                final categories = allCategories
                    .where((c) => c.income == showIncome)
                    .toList();

                return StreamBuilder<List<Transaction>>(
                  stream: database.getTransactionsInTimeRangeFromCategories(
                    startOfMonth,
                    endOfMonth,
                    null,
                    null,
                    true,
                    null,
                    null,
                    null,
                  ),
                  builder: (context, transSnap) {
                    final transactions = transSnap.data ?? [];

                    Map<String, double> categoryTotals = {};
                    double totalExpenses = 0;
                    double totalIncome = 0;

                    for (var t in transactions) {
                      if (!t.paid) continue;
                      if (selectedWalletPk != null &&
                          t.walletFk != selectedWalletPk) continue;

                      if (t.income) {
                        totalIncome += t.amount.abs();
                      } else {
                        totalExpenses += t.amount.abs();
                      }
                      if (t.income == showIncome) {
                        categoryTotals[t.categoryFk] =
                            (categoryTotals[t.categoryFk] ?? 0) +
                                t.amount.abs();
                      }
                    }

                    final double activeTotal =
                        showIncome ? totalIncome : totalExpenses;

                    List<_ChartSegment> segments = [];
                    for (var cat in categories) {
                      final amt = categoryTotals[cat.categoryPk] ?? 0;
                      if (amt > 0) {
                        segments.add(_ChartSegment(
                            amount: amt, color: _parseColor(cat.colour)));
                      }
                    }

                    // توزيع الفئات بنفس هندسة الصورة المرفقة:
                    // الصف 1: 4 فئات (0, 1, 2, 3)
                    // الصف 2 والصف 3 (حول الدائرة): يمين (4, 6) ويسار (5, 7)
                    // الصف 4 وما بعده: باقي الفئات + زر (+)
                    final topRow = categories.take(4).toList();
                    final rightCol = <TransactionCategory>[];
                    final leftCol = <TransactionCategory>[];
                    if (categories.length > 4) rightCol.add(categories[4]);
                    if (categories.length > 5) leftCol.add(categories[5]);
                    if (categories.length > 6) rightCol.add(categories[6]);
                    if (categories.length > 7) leftCol.add(categories[7]);
                    final bottomCats = categories.skip(8).toList();

                    final activeWalletName = selectedWalletPk == null
                        ? "كل الحسابات"
                        : wallets
                            .firstWhere(
                              (w) => w.walletPk == selectedWalletPk,
                              orElse: () => wallets.first,
                            )
                            .name;

                    return Column(
                      children: [
                        // 1. الهيدر العلوي المطابق للصورة (كل الحسابات + إجمالي الرصيد)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // زر التعديل / التبديل بين الدخل والمصروفات
                              IconButton(
                                icon: Icon(
                                  showIncome
                                      ? Icons.trending_up_rounded
                                      : Icons.edit_outlined,
                                  color: Colors.grey.shade700,
                                ),
                                onPressed: () =>
                                    setState(() => showIncome = !showIncome),
                              ),
                              // اسم الحساب وإجمالي الرصيد
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (wallets.isEmpty) return;
                                  setState(() {
                                    if (selectedWalletPk == null) {
                                      selectedWalletPk = wallets.first.walletPk;
                                    } else {
                                      int idx = wallets.indexWhere((w) =>
                                          w.walletPk == selectedWalletPk);
                                      if (idx + 1 < wallets.length) {
                                        selectedWalletPk =
                                            wallets[idx + 1].walletPk;
                                      } else {
                                        selectedWalletPk = null;
                                      }
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: Column(
                                    children: [
                                      Text(
                                        activeWalletName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${_formatAmount(totalIncome - totalExpenses)} ل.د",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // أيقونة الحساب
                              IconButton(
                                icon: Icon(
                                  Icons.account_circle_outlined,
                                  color: Colors.grey.shade700,
                                ),
                                onPressed: () =>
                                    setState(() => showIncome = !showIncome),
                              ),
                            ],
                          ),
                        ),

                        // 2. شريط التنقل بين الأشهر (« 30 نوفمبر 2026 »)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.keyboard_double_arrow_right),
                                onPressed: () {
                                  setState(() {
                                    selectedMonth = DateTime(
                                        selectedMonth.year,
                                        selectedMonth.month - 1,
                                        1);
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.black87, width: 1.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day}",
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      monthLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down,
                                        size: 18),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.keyboard_double_arrow_left),
                                onPressed: () {
                                  setState(() {
                                    selectedMonth = DateTime(
                                        selectedMonth.year,
                                        selectedMonth.month + 1,
                                        1);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 3. شبكة الفئات المحيطة بالحلقة البيانية (تصميم 1Money المطابق للصورة)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              children: [
                                // الصف العلوي: 4 فئات
                                Row(
                                  children: List.generate(4, (i) {
                                    if (i < topRow.length) {
                                      final cat = topRow[i];
                                      return Expanded(
                                        child: _buildCategoryCell(
                                          context,
                                          cat,
                                          categoryTotals[cat.categoryPk] ?? 0,
                                          wallets,
                                        ),
                                      );
                                    }
                                    return const Expanded(child: SizedBox());
                                  }),
                                ),

                                const SizedBox(height: 6),

                                // القسم الأوسط: عمود يمين (فئتان) + الحلقة البيانية في المنتصف + عمود يسار (فئتان)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // العمود الأيمن (فئتان)
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        children: [
                                          if (rightCol.isNotEmpty)
                                            _buildCategoryCell(
                                              context,
                                              rightCol[0],
                                              categoryTotals[
                                                      rightCol[0].categoryPk] ??
                                                  0,
                                              wallets,
                                            ),
                                          const SizedBox(height: 8),
                                          if (rightCol.length > 1)
                                            _buildCategoryCell(
                                              context,
                                              rightCol[1],
                                              categoryTotals[
                                                      rightCol[1].categoryPk] ??
                                                  0,
                                              wallets,
                                            ),
                                        ],
                                      ),
                                    ),

                                    // الحلقة البيانية المركزية (النفقات / الدخل)
                                    Expanded(
                                      flex: 2,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => showIncome = !showIncome),
                                        child: Center(
                                          child: SizedBox(
                                            width: 170,
                                            height: 170,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CustomPaint(
                                                  size: const Size(170, 170),
                                                  painter:
                                                      _OneMoneyDonutPainter(
                                                          segments: segments),
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      showIncome
                                                          ? "الدخل"
                                                          : "النفقات",
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "${_formatAmount(activeTotal)} ل.د",
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: showIncome
                                                            ? Colors.green
                                                            : Colors.redAccent,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "${_formatAmount(showIncome ? totalExpenses : totalIncome)} ل.د",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: showIncome
                                                            ? Colors.redAccent
                                                            : Colors.teal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // العمود الأيسر (فئتان)
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        children: [
                                          if (leftCol.isNotEmpty)
                                            _buildCategoryCell(
                                              context,
                                              leftCol[0],
                                              categoryTotals[
                                                      leftCol[0].categoryPk] ??
                                                  0,
                                              wallets,
                                            ),
                                          const SizedBox(height: 8),
                                          if (leftCol.length > 1)
                                            _buildCategoryCell(
                                              context,
                                              leftCol[1],
                                              categoryTotals[
                                                      leftCol[1].categoryPk] ??
                                                  0,
                                              wallets,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // الصف السفلي: الفئات المتبقية + زر (+) لإضافة فئة جديدة
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: bottomCats.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == bottomCats.length) {
                                      return _buildAddCategoryCell(context);
                                    }
                                    final cat = bottomCats[index];
                                    return _buildCategoryCell(
                                      context,
                                      cat,
                                      categoryTotals[cat.categoryPk] ?? 0,
                                      wallets,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChartSegment {
  final double amount;
  final Color color;
  _ChartSegment({required this.amount, required this.color});
}

class _OneMoneyDonutPainter extends CustomPainter {
  final List<_ChartSegment> segments;
  _OneMoneyDonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    double total = segments.fold(0, (sum, item) => sum + item.amount);
    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    for (var seg in segments) {
      final sweepAngle = (seg.amount / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.max(0.01, sweepAngle - 0.03),
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
