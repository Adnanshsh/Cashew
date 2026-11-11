import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/colors.dart';

class OneMoneyQuickEntryPage extends StatefulWidget {
  const OneMoneyQuickEntryPage({Key? key}) : super(key: key);

  @override
  State<OneMoneyQuickEntryPage> createState() => _OneMoneyQuickEntryPageState();
}

class _OneMoneyQuickEntryPageState extends State<OneMoneyQuickEntryPage> {
  String? selectedWalletPk;
  bool showIncome = false; // التبديل بين المصروفات والدخل

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

  // لوحة مفاتيح 1Money الاحترافية مع آلة حاسبة مدمجة
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
        if (clean.endsWith('+') || clean.endsWith('-') || clean.endsWith('*') || clean.endsWith('/')) {
          clean = clean.substring(0, clean.length - 1);
        }
        // حساب بسيط للعمليات الأساسية
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
      builder: (context) {
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
                      !["+", "-", "×", "÷"].contains(expression[expression.length - 1])) {
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الشريط العلوي الملون بأسلوب 1Money (الحساب -> الفئة)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        // اختيار الحساب/المحفظة
                        InkWell(
                          onTap: () {
                            if (wallets.length > 1) {
                              int nextIdx = (wallets.indexOf(currentWallet) + 1) % wallets.length;
                              setSheetState(() {
                                currentWalletPk = wallets[nextIdx].walletPk;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  currentWallet.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
                        ),
                        // اسم الفئة وأيقونتها
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

                  // شاشة عرض المبلغ الكبير
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: catColor.withOpacity(0.12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category.income ? "إضافة دخل" : "إضافة مصروف",
                          style: TextStyle(color: catColor, fontWeight: FontWeight.w600),
                        ),
                        Expanded(
                          child: Text(
                            "$expression د.ل",
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

                  // حقل الملاحظات
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),

                  // شبكة أزرار الحاسبة المتلاصقة على طريقة 1Money
                   Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  SizedBox(
                    height: 250,
                    child: Row(
                      children: [
                        // الأرقام والعمليات
                        Expanded(
                          flex: 3,
                          child: GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            childAspectRatio: 1.55,
                            children: ["7", "8", "9", "4", "5", "6", "1", "2", "3", ".", "0", "C"].map((k) {
                              return InkWell(
                                onTap: () => onKey(k),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withOpacity(0.1), width: 0.5),
                                  ),
                                  child: Text(
                                    k,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        // العمود الجانبي للعمليات والحفظ
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
                                        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 0.5),
                                      ),
                                      child: Text(
                                        op,
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: catColor),
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
                                    double finalAmount = evaluateExpression(expression);
                                    if (finalAmount <= 0) return;

                                    await database.createOrUpdateTransaction(
                                      insert: true,
                                      Transaction(
                                        transactionPk: "-1",
                                        name: noteController.text.trim(),
                                        amount: category.income ? finalAmount : -finalAmount,
                                        note: "",
                                        categoryFk: category.categoryPk,
                                        walletFk: currentWalletPk,
                                        dateCreated: DateTime.now(),
                                        income: category.income,
                                        paid: true,
                                        skipPaid: false,
                                      ),
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    color: catColor,
                                    child: Icon(
                                      hasOperator ? Icons.drag_handle : Icons.check,
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<TransactionWallet>>(
          stream: database.getAllPinnedWallets(HomePageWidgetDisplay.WalletList).$1,
          builder: (context, walletSnap) {
            final wallets = walletSnap.data ?? [];
            if (wallets.isNotEmpty && selectedWalletPk == null) {
              selectedWalletPk = wallets.first.walletPk;
            }

            return StreamBuilder<List<TransactionCategory>>(
              stream: database.watchAllCategories(),
              builder: (context, catSnap) {
                final allCategories = catSnap.data ?? [];
                final filteredCategories = allCategories.where((c) => c.income == showIncome).toList();

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

                    // حساب مجموع كل فئة لهذا الشهر
                    Map<String, double> categoryTotals = {};
                    double totalExpenses = 0;
                    double totalIncome = 0;

                    for (var t in transactions) {
                      if (!t.paid) continue;
                      if (t.income) {
                        totalIncome += t.amount.abs();
                      } else {
                        totalExpenses += t.amount.abs();
                      }
                      if (t.income == showIncome) {
                        categoryTotals[t.categoryFk] = (categoryTotals[t.categoryFk] ?? 0) + t.amount.abs();
                      }
                    }

                    final double activeTotal = showIncome ? totalIncome : totalExpenses;

                    // تجهيز مقاطع الدائرة البيانية (Donut Chart)
                    List<_ChartSegment> segments = [];
                    for (var cat in filteredCategories) {
                      final double amt = categoryTotals[cat.categoryPk] ?? 0;
                      if (amt > 0) {
                        segments.add(_ChartSegment(amount: amt, color: _parseColor(cat.colour)));
                      }
                    }

                    return Column(
                      children: [
                        // 1. الهيدر العلوي بأسلوب 1Money (المحافظ + التبديل بين المصروفات والدخل)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            children: [
                              // شريط المحافظ الأفقي
                              if (wallets.isNotEmpty)
                                SizedBox(
                                  height: 40,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: wallets.length,
                                    itemBuilder: (context, idx) {
                                      final w = wallets[idx];
                                      final isSel = w.walletPk == selectedWalletPk;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: ChoiceChip(
                                          label: Text(
                                            w.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSel ? Colors.white : null,
                                            ),
                                          ),
                                          selected: isSel,
                                          selectedColor: const Color(0xFF2E7D32),
                                          onSelected: (_) => setState(() => selectedWalletPk = w.walletPk),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 10),
                              // أزرار التبديل (المصروفات / الدخل)
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                pading: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => showIncome = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: !showIncome ? Colors.redAccent.withOpacity(0.15) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                "المصروفات",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: !showIncome ? Colors.redAccent : Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                "${_formatAmount(totalExpenses)} د.ل",
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: !showIncome ? Colors.redAccent : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => showIncome = true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: showIncome ? Colors.green.withOpacity(0.15) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                "الدخل",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: showIncome ? Colors.green : Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                "${_formatAmount(totalIncome)} د.ل",
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: showIncome ? Colors.green : Colors.grey,
                                                ),
                                              ),
                                            ],
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

                        // 2. الدائرة البيانية التفاعلية في المنتصف (1Money Donut Chart)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 175,
                            height: 175,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(175, 175),
                                  painter: _OneMoneyDonutPainter(segments: segments),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      showIncome ? "إجمالي الدخل" : "إجمالي المصروفات",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${_formatAmount(activeTotal)} د.ل",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: showIncome ? Colors.green : Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "الصافي: ${_formatAmount(totalIncome - totalExpenses)}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 3. شبكة أيقونات 1Money مع المبلغ المصروف تحت كل فئة
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
                              final cat = filteredCategories[index];
                              final catColor = _parseColor(cat.colour);
                              final double spent = categoryTotals[cat.categoryPk] ?? 0;

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
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      cat.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: spent > 0 ? catColor : catColor.withOpacity(0.18),
                                        boxShadow: spent > 0
                                            ? [
                                                BoxShadow(
                                                  color: catColor.withOpacity(0.35),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                )
                                              ]
                                            : [],
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Image.asset(
                                        "assets/categories/${cat.iconName ?? 'cash-bill-dollar.png'}",
                                        color: spent > 0 ? Colors.white : null,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      spent > 0 ? "${_formatAmount(spent)} د.ل" : "0",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: spent > 0 ? FontWeight.bold : FontWeight.normal,
                                        color: spent > 0 ? catColor : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
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
        sweepAngle - 0.03, // مسافة فاصلة أنيقة بين الألوان
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
