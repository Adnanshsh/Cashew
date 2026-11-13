import 'package:flutter/material.dart';
import 'package:budget/pages/homePage/homePageOneMoneyDial.dart';

class OneMoneyQuickEntryPage extends StatelessWidget {
  const OneMoneyQuickEntryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: HomePageOneMoneyDial(),
        ),
      ),
    );
  }
}
