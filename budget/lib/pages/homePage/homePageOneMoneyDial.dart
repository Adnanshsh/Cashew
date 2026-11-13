import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/transactionsSearchPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openContainerNavigation.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/textWidgets.dart';

class HomePageOneMoneyDial extends StatefulWidget {
  const HomePageOneMoneyDial({super.key});

  @override
  State<HomePageOneMoneyDial> createState() => _HomePageOneMoneyDialState();
}

class _HomePageOneMoneyDialState extends State<HomePageOneMoneyDial> {
  bool showIncome = false;
  String? selectedWalletPk;

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return StreamBuilder<List<TransactionWallet>>(
      stream: database.getAllPinnedWallets(HomePageWidgetDisplay.WalletList).$1,
      builder: (context, walletSnap) {
        final wallets = walletSnap.data ?? [];
        if (wallets.isNotEmpty && selectedWalletPk == null) {
          selectedWalletPk = appStateSettings["selectedWalletPk"] ?? wallets.first.walletPk;
        }

        return StreamBuilder<List<TransactionCategory>>(
          stream: database.watchAllCategories(),
          builder: (context, catSnap) {
            final allCategories = catSnap.data ?? [];
            final categories = allCategories.where((c) => c.income == showIncome).toList();

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
                double totalExpense = 0;
                double totalIncome = 0;

                for (var t in transactions) {
                  if (!t.paid) continue;
                  if (selectedWalletPk != null && t.walletFk != selectedWalletPk) continue;

                  if (t.income) {
                    totalIncome += t.amount.abs();
                  } else {
                    totalExpense += t.amount.abs();
                  }

                  if (t.income == showIncome) {
                    categoryTotals[t.categoryFk] =
                        (categoryTotals[t.categoryFk] ?? 0) + t.amount.abs();
                  }
                }

                final double activeTotal = showIncome ? totalIncome : totalExpense;

                // تقسيم الفئات: أول 8 فئات تحيط بالدائرة البيانية (أسلوب 1Money الأصلي) والباقي في شبكة سفلية
                final dialCategories = categories.take(8).toList();
                final extraCategories = categories.skip(8).toList();

                List<_DialSegment> segments = [];
                for (var cat in categories) {
                  final amt = categoryTotals[cat.categoryPk] ?? 0;
                  if (amt > 0) {
                    segments.add(_DialSegment(amount: amt, color: _parseColor(cat.colour)));
                  }
                }

                return Column(
                  children: [
                    // 1. شريط اختيار المحفظة والتبديل بين المصروفات والدخل
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          if (wallets.isNotEmpty)
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: wallets.length + 1,
                                  itemBuilder: (context, idx) {
                                    if (idx == 0) {
                                      final isAll = selectedWalletPk == null;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: ChoiceChip(
                                          label: const Text("الكل"),
                                          selected: isAll,
                                          onSelected: (_) => setState(() => selectedWalletPk = null),
                                        ),
                                      );
                                    }
                                    final w = wallets[idx - 1];
                                    final isSel = w.walletPk == selectedWalletPk;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: ChoiceChip(
                                        label: Text(w.name),
                                        selected: isSel,
                                        onSelected: (_) => setState(() => selectedWalletPk = w.walletPk),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 2. القرص الدائري التفاعلي (1Money Circular Dial)
                    SizedBox(
                      height: 350,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                          const double orbitRadius = 122.0;

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // الحلقة البيانية في المنتصف
                              GestureDetector(
                                onTap: () => setState(() => showIncome = !showIncome),
                                child: SizedBox(
                                  width: 145,
                                  height: 145,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(145, 145),
                                        painter: _OneMoneyRingPainter(segments: segments),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextFont(
                                            text: showIncome ? "الدخل" : "المصروفات",
                                            fontSize: 12,
                                            textColor: Colors.grey,
                                          ),
                                          const SizedBox(height: 2),
                                          TextFont(
                                            text: "${_formatAmount(activeTotal)} د.ل",
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            textColor: showIncome ? Colors.green : Colors.redAccent,
                                          ),
                                          const SizedBox(height: 2),
                                          TextFont(
                                            text: "اضغط للتبديل",
                                            fontSize: 10,
                                            textColor: Colors.grey.withOpacity(0.7),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // الأيقونات المحيطة بالدائرة (8 فئات رئيسية)
                              ...List.generate(dialCategories.length, (index) {
                                final cat = dialCategories[index];
                                final angle = (2 * math.pi * index / dialCategories.length) - (math.pi / 2);
                                final dx = center.dx + orbitRadius * math.cos(angle) - 38;
                                final dy = center.dy + orbitRadius * math.sin(angle) - 38;
                                final spent = categoryTotals[cat.categoryPk] ?? 0;

                                return Positioned(
                                  left: dx,
                                  top: dy,
                                  width: 76,
                                  height: 76,
                                  child: _buildCategoryNode(context, cat, spent),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),

                    // 3. بقية الفئات في شبكة مرتبة بالأسفل
                    if (extraCategories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: extraCategories.length,
                          itemBuilder: (context, index) {
                            final cat = extraCategories[index];
                            final spent = categoryTotals[cat.categoryPk] ?? 0;
                            return _buildCategoryNode(context, cat, spent);
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
    );
  }

  Widget _buildCategoryNode(BuildContext context, TransactionCategory cat, double spent) {
    final catColor = _parseColor(cat.colour);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        pushRoute(
          context,
          AddTransactionPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
            selectedCategory: cat,
          ),
        );
      },
      onLongPress: () {
        pushRoute(
          context,
          TransactionsSearchPage(
            initialFilters: SearchFilters(
              categoryPks: [cat.categoryPk],
            ),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: spent > 0 ? catColor : catColor.withOpacity(0.18),
            ),
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              "assets/categories/${cat.iconName ?? 'cash-bill-dollar.png'}",
              color: spent > 0 ? Colors.white : null,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            spent > 0 ? _formatAmount(spent) : "0",
            style: TextStyle(
              fontSize: 11,
              fontWeight: spent > 0 ? FontWeight.bold : FontWeight.normal,
              color: spent > 0 ? catColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialSegment {
  final double amount;
  final Color color;
  _DialSegment({required this.amount, required this.color});
}

class _OneMoneyRingPainter extends CustomPainter {
  final List<_DialSegment> segments;
  _OneMoneyRingPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

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
        ..strokeWidth = strokeWidth;

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
