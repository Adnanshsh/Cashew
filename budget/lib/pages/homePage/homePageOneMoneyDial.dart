import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/colors.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/pages/addBudgetPage.dart';
import 'package:budget/pages/transactionsSearchPage.dart';
import 'package:budget/widgets/openPopup.dart';

class HomePageOneMoneyDial extends StatefulWidget {
  const HomePageOneMoneyDial({Key? key}) : super(key: key);

  @override
  State<HomePageOneMoneyDial> createState() => _HomePageOneMoneyDialState();
}

class _HomePageOneMoneyDialState extends State<HomePageOneMoneyDial> {
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

  // 1. نافذة الضغط لمرة واحدة: حاسبة 1Money المقسومة (من الحساب | إلى الفئة)
  void _open1MoneyCalculatorSheet(
    BuildContext context,
    TransactionCategory category,
    List<TransactionWallet> wallets,
    String initialWalletPk,
  ) {
    String expression = "0";
    String currentWalletPk = initialWalletPk;
    DateTime selectedDate = DateTime.now();
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
                if (key == "⌫") {
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
            final walletColor = _parseColor(currentWallet.colour);

            final bool hasOperator = expression.contains('+') ||
                expression.contains('-') ||
                expression.contains('×') ||
                expression.contains('÷');

            final dateStr =
                "${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}";
            final isToday = selectedDate.year == DateTime.now().year &&
                selectedDate.month == DateTime.now().month &&
                selectedDate.day == DateTime.now().day;

            return Container(
              margin: const EdgeInsets.only(top: 60),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 22),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // الهيدر المقسوم (من الحساب | إلى الفئة)
                        SizedBox(
                          height: 76,
                          child: Row(
                            children: [
                              // النصف الأيمن: من الحساب
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (wallets.length > 1) {
                                      int nextIdx =
                                          (wallets.indexOf(currentWallet) + 1) %
                                              wallets.length;
                                      setSheetState(() {
                                        currentWalletPk =
                                            wallets[nextIdx].walletPk;
                                      });
                                    }
                                  },
                                  child: Container(
                                    color: walletColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.income
                                              ? "إلى الحساب"
                                              : "من الحساب",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentWallet.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // النصف الأيسر: إلى الفئة
                              Expanded(
                                child: Container(
                                  color: catColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        category.income
                                            ? "من الفئة"
                                            : "إلى الفئة",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        category.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // عنوان "مصروف" والمبلغ الكبير في المنتصف
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Column(
                            children: [
                              Text(
                                category.income ? "دخل" : "مصروف",
                                style: TextStyle(
                                  color: catColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$expression ل.د",
                                style: TextStyle(
                                  color: catColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // حقل الملاحظات المستطيل
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: TextField(
                            controller: noteController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: "ملاحظات ...",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.25)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.25)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // شبكة الآلة الحاسبة (4 أعمدة مطابقة للصورة)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 255,
                            child: Row(
                              children: [
                                // العمود الأول (يسار): ÷ × - +
                                Expanded(
                                  child: Column(
                                    children: [
                                      for (var op in ["÷", "×", "-", "+"])
                                        Expanded(
                                          child: _calcKeyButton(
                                            context,
                                            label: op,
                                            onTap: () => onKey(op),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // العمود الثاني والثالث: الأرقام 7-8-9 / 4-5-6 / 1-2-3 / ل.د-0-.
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "7",
                                                    onTap: () => onKey("7"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "8",
                                                    onTap: () => onKey("8"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "9",
                                                    onTap: () => onKey("9"))),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "4",
                                                    onTap: () => onKey("4"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "5",
                                                    onTap: () => onKey("5"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "6",
                                                    onTap: () => onKey("6"))),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "1",
                                                    onTap: () => onKey("1"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "2",
                                                    onTap: () => onKey("2"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "3",
                                                    onTap: () => onKey("3"))),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "ل.د",
                                                    fontSize: 16,
                                                    onTap: () {})),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: "0",
                                                    onTap: () => onKey("0"))),
                                            Expanded(
                                                child: _calcKeyButton(context,
                                                    label: ".",
                                                    onTap: () => onKey("."))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // العمود الرابع (يمين): مسح، تقويم، وزر الحفظ الكبير ✓
                                Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: _calcIconButton(
                                          context,
                                          icon: Icons.backspace_outlined,
                                          onTap: () => onKey("⌫"),
                                          onLongPress: () => setSheetState(
                                              () => expression = "0"),
                                        ),
                                      ),
                                      Expanded(
                                        child: _calcIconButton(
                                          context,
                                          icon: Icons.calendar_today_outlined,
                                          onTap: () async {
                                            final picked =
                                                await showDatePicker(
                                              context: context,
                                              initialDate: selectedDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2035),
                                            );
                                            if (picked != null) {
                                              setSheetState(
                                                  () => selectedDate = picked);
                                            }
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            onTap: () async {
                                              if (hasOperator) {
                                                onKey("=");
                                                return;
                                              }
                                              double finalAmount =
                                                  evaluateExpression(
                                                      expression);
                                              if (finalAmount <= 0) return;

                                              await database
                                                  .createOrUpdateTransaction(
                                                insert: true,
                                                Transaction(
                                                  transactionPk: "-1",
                                                  name: noteController.text
                                                      .trim(),
                                                  amount: category.income
                                                      ? finalAmount
                                                      : -finalAmount,
                                                  note: "",
                                                  categoryFk:
                                                      category.categoryPk,
                                                  walletFk: currentWalletPk,
                                                  dateCreated: selectedDate,
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
                                              decoration: BoxDecoration(
                                                color: catColor,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
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
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // التاريخ في الأسفل
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            isToday ? "اليوم، $dateStr" : dateStr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // الأيقونتان العائمتان فوق الحد الفاصل (أيقونة الحساب وأيقونة الفئة)
                  Positioned(
                    top: 0,
                    right: 22,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Icon(Icons.credit_card,
                          color: walletColor, size: 24),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 22,
                    child: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Image.asset(
                        "assets/categories/${category.iconName ?? 'cash-bill-dollar.png'}",
                        color: catColor,
                      ),
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

  // 2. نافذة الضغط المطول: بطاقة تفاصيل الفئة السفلية (المعاملات | الميزانية | تعديل)
  void _openCategoryLongPressSheet(
    BuildContext context,
    TransactionCategory category,
    double spent,
    int txCount,
    String monthLabel,
  ) {
    final catColor = _parseColor(category.colour);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الجزء العلوي الملون بلون الفئة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${_formatAmount(spent)} ل.د",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              category.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            txCount == 0
                                ? "لا يوجد معاملات"
                                : "$txCount معاملات",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // شريط تقدم الميزانية
                        Row(
                          children: [
                            const Text(
                              "0%",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: spent > 0 ? 0.25 : 0.0,
                                  minHeight: 7,
                                  backgroundColor: Colors.white24,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "0 ل.د",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            Text(
                              monthLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // الأزرار السفلية الثلاثة: المعاملات | الميزانية | تعديل
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _longPressActionItem(
                          icon: Icons.receipt_long_outlined,
                          label: "المعاملات",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            pushRoute(context, const TransactionsSearchPage());
                          },
                        ),
                        _longPressActionItem(
                          icon: Icons.speed_outlined,
                          label: "الميزانية",
                          color: Colors.grey.shade700,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            pushRoute(
                              context,
                              AddBudgetPage(
                                routesToPopAfterDelete:
                                    RoutesToPopAfterDelete.None,
                              ),
                            );
                          },
                        ),
                        _longPressActionItem(
                          icon: Icons.edit_outlined,
                          label: "تعديل",
                          color: Colors.amber.shade700,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            pushRoute(
                              context,
                              AddCategoryPage(
                                routesToPopAfterDelete:
                                    RoutesToPopAfterDelete.None,
                                category: category,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // الأيقونة الدائرية البيضاء العائمة في الأعلى
            Positioned(
              top: 0,
              left: 22,
              child: Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Image.asset(
                  "assets/categories/${category.iconName ?? 'cash-bill-dollar.png'}",
                  color: catColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _longPressActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcKeyButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    double fontSize = 22,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _calcIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 22, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _buildCategoryCell(
    BuildContext context,
    TransactionCategory cat,
    double spent,
    int txCount,
    String monthLabel,
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
      onLongPress: () {
        _openCategoryLongPressSheet(
          context,
          cat,
          spent,
          txCount,
          monthLabel,
        );
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
          AddCategoryPage(
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

    return StreamBuilder<List<TransactionWallet>>(
      stream:
          database.getAllPinnedWallets(HomePageWidgetDisplay.WalletList).$1,
      builder: (context, walletSnap) {
        final wallets = walletSnap.data ?? [];

        return StreamBuilder<List<TransactionCategory>>(
          stream: database.watchAllCategories(),
          builder: (context, catSnap) {
            final allCategories = catSnap.data ?? [];
            final categories =
                allCategories.where((c) => c.income == showIncome).toList();

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
                Map<String, int> categoryCounts = {};
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
                    categoryCounts[t.categoryFk] =
                        (categoryCounts[t.categoryFk] ?? 0) + 1;
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

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
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
                      Row(
                        children: List.generate(4, (i) {
                          if (i < topRow.length) {
                            final cat = topRow[i];
                            return Expanded(
                              child: _buildCategoryCell(
                                context,
                                cat,
                                categoryTotals[cat.categoryPk] ?? 0,
                                categoryCounts[cat.categoryPk] ?? 0,
                                monthLabel,
                                wallets,
                              ),
                            );
                          }
                          return const Expanded(child: SizedBox());
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                    categoryCounts[
                                            rightCol[0].categoryPk] ??
                                        0,
                                    monthLabel,
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
                                    categoryCounts[
                                            rightCol[1].categoryPk] ??
                                        0,
                                    monthLabel,
                                    wallets,
                                  ),
                              ],
                            ),
                          ),
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
                                    categoryCounts[
                                            leftCol[0].categoryPk] ??
                                        0,
                                    monthLabel,
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
                                    categoryCounts[
                                            leftCol[1].categoryPk] ??
                                        0,
                                    monthLabel,
                                    wallets,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                            categoryCounts[cat.categoryPk] ?? 0,
                            monthLabel,
                            wallets,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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

  @
