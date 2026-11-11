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
  bool showIncome = false;

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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
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
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  SizedBox(
                    height: 250,
                    child: Row(
                      children: [
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
