import 'package:budget/database/tables.dart';
import 'package:budget/pages/expense_tools/spending_plan.dart';
import 'package:budget/widgets/one_money_category_badge.dart';
import 'package:budget/pages/homePage/homePageOneMoneyDial.dart';
import 'package:budget/pages/oneMoneyPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('1Money home builds the spending entry above the dial',
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      // Check the actual quick-entry page tree without mounting the
      // database-backed plan and dial in this layout test.
      final page = const OneMoneyQuickEntryPage().build(context) as Scaffold;
      final safeArea = page.body! as SafeArea;
      final scroll = safeArea.child as SingleChildScrollView;
      final content = scroll.child! as Column;
      expect(content.children, [
        isA<SpendingPlanEntry>(),
        isA<HomePageOneMoneyDial>(),
      ]);
      return const SizedBox.shrink();
    }));
  });
  testWidgets('category badge uses the dial’s circular tinted icon',
      (tester) async {
    final category = TransactionCategory(
        categoryPk: 'food',
        name: 'Food',
        colour: '#336699',
        iconName: 'cash-bill-dollar.png',
        dateCreated: DateTime(2026, 11, 28),
        order: 1,
        income: false);
    await tester.pumpWidget(Builder(builder: (context) {
      const tone = Color(0xff336699);
      final badge =
          OneMoneyCategoryBadge(category: category).build(context) as Container;
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color?.value, tone.withOpacity(0.14).value);
      expect((badge.child! as Image).color?.value, tone.value);
      return const SizedBox.shrink();
    }));
  });
}
