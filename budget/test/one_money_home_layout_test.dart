import 'package:budget/pages/expense_tools/spending_plan.dart';
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
}
