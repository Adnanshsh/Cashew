import 'package:budget/pages/expense_tools/spending_plan.dart';
import 'package:flutter/material.dart';
import 'package:budget/pages/homePage/homePageOneMoneyDial.dart';

class OneMoneyQuickEntryPage extends StatelessWidget {
  const OneMoneyQuickEntryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SpendingPlanEntry(),
              HomePageOneMoneyDial(),
            ],
          ),
        ),
      ),
    );
  }
}
