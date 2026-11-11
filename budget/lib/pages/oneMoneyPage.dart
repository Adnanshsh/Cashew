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

  // فتح لوحة الأرقام السريعة فور الضغط على أي فئة (بأسلوب 1Money)
  void _openQuickNumpad(BuildContext context, TransactionCategory category, String walletPk) {
    String amountText = "0";
    TextEditingController noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onKeyTap(String val) {
              setSheetState(() {
                if (val == "C") {
                  amountText = "0";
                } else if (val == "⌫") {
                  amountText = amountText.length > 1
                      ? amountText.substring(0, amountText.length - 1)
                      : "0";
                } else if (val == ".") {
                  if (!amountText.contains(".")) amountText += ".";
                } else {
                  amountText = (amountText == "0") ? val : amountText + val;
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: HexColor(category.colour ?? "#4CAF50").withOpacity(0.2),
                        child: Image.asset(
                          "assets/categories/${category.iconName ?? 'cash-bill-dollar.png'}",
                          width: 26,
                          height: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "$amountText د.ل",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: category.income ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: "إضافة ملاحظة (اختياري)...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      ...["7", "8", "9", "⌫", "4", "5", "6", "C", "1", "2", "3", "."].map((key) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).cardColor,
                            foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                            elevation: 1,
                          ),
                          onPressed: () => onKeyTap(key),
                          child: Text(key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Theme.of(context).cardColor,
                          ),
                          onPressed: () => onKeyTap("0"),
                          child: const Text("0", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: HexColor(category.colour ?? "#2196F3"),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            double finalAmount = double.tryParse(amountText) ?? 0;
                            if (finalAmount <= 0) return;

                            await database.createOrUpdateTransaction(
                              insert: true,
                              Transaction(
                                transactionPk: "-1",
                                name: noteController.text.trim(),
                                amount: category.income ? finalAmount : -finalAmount,
                                note: "",
                                categoryFk: category.categoryPk,
                                walletFk: walletPk,
                                dateCreated: DateTime.now(),
                                income: category.income,
                                paid: true,
                                skipPaid: false,
                              ),
                            );
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text("حفظ المعاملة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الإدخال السريع (1Money)"),
        centerTitle: true,
      ),
      body: StreamBuilder<List<TransactionWallet>>(
        stream: database.getAllPinnedWallets(HomePageWidgetDisplay.WalletList).$1,
        builder: (context, walletSnapshot) {
          final wallets = walletSnapshot.data ?? [];
          if (wallets.isNotEmpty && selectedWalletPk == null) {
            selectedWalletPk = wallets.first.walletPk;
          }

          return Column(
            children: [
              if (wallets.isNotEmpty)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = wallet.walletPk == selectedWalletPk;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(wallet.name),
                          selected: isSelected,
                          onSelected: (_) => setState(() => selectedWalletPk = wallet.walletPk),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<TransactionCategory>>(
                  stream: database.watchAllCategories(),
                  builder: (context, catSnapshot) {
                    final categories = catSnapshot.data ?? [];
                    if (categories.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (selectedWalletPk != null) {
                              _openQuickNumpad(context, cat, selectedWalletPk!);
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HexColor(cat.colour ?? "#607D8B").withOpacity(0.18),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  "assets/categories/${cat.iconName ?? 'cash-bill-dollar.png'}",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
