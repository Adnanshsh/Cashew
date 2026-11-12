import 'dart:async';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/breathingAnimation.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/moreIcons.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/statusBox.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/transactionEntry/transactionEntry.dart';
import 'package:budget/widgets/viewAllTransactionsButton.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sa3_liquid/sa3_liquid.dart';
import 'package:budget/widgets/openContainerNavigation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

bool premiumPopupEnabled = false;
bool tryStoreEnabled = false;
StreamSubscription? purchaseListener;
Map<String, ProductDetails> storeProducts = {};
Map<String, String> productIDs = {
  'yearly': getPlatform(ignoreEmulation: true) == PlatformOS.isIOS
      ? 'cashew.pro.yearly'
      : 'cashew.pro.yearly',
  'monthly': getPlatform(ignoreEmulation: true) == PlatformOS.isIOS
      ? 'cashew.pro.monthly'
      : 'cashew.pro.monthly',
  'lifetime': getPlatform(ignoreEmulation: true) == PlatformOS.isIOS
      ? 'cashew.pro.life'
      : 'cashew.pro.lifetime',
};

class PremiumPage extends StatelessWidget {
  const PremiumPage({
    this.canDismiss = false,
    required this.popRouteWithPurchase,
    super.key,
  });
  final bool canDismiss;
  final bool popRouteWithPurchase;

  @override
  Widget build(BuildContext context) {
    appStateSettings["purchaseID"] = productIDs["lifetime"];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cashew Pro"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CashewProBanner(large: true),
            const SizedBox(height: 16),
            TextFont(
              text: "تم تفعيل نسخة Cashew Pro (مدى الحياة) بالكامل",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FreePremiumMessage extends StatefulWidget {
  const FreePremiumMessage({super.key});

  @override
  State<FreePremiumMessage> createState() => _FreePremiumMessageState();
}

class _FreePremiumMessageState extends State<FreePremiumMessage> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class CashewProBanner extends StatelessWidget {
  const CashewProBanner({this.large = false, this.fontColor, super.key});
  final bool large;
  final Color? fontColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      direction: Axis.horizontal,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextFont(
          text: globalAppName,
          fontWeight: FontWeight.bold,
          fontSize: large ? 35 : 23,
          textColor: fontColor ?? Colors.black,
        ),
        const SizedBox(width: 2),
        TextPill(fontSize: large ? 21 : 15, text: "Pro"),
      ],
    );
  }
}

class TextPill extends StatelessWidget {
  const TextPill({required this.text, required this.fontSize, super.key});
  final String text;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 5),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadiusDirectional.circular(100),
        boxShadow: boxShadowGeneral(context),
      ),
      child: TextFont(
        text: text,
        textColor: Theme.of(context).colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
    );
  }
}

openManagePurchase() {}

class ManageSubscription extends StatelessWidget {
  const ManageSubscription({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

void listenToPurchaseUpdated({
  required List<PurchaseDetails> purchaseDetailsList,
  required BuildContext context,
  required bool popRouteWithPurchase,
}) {}

Future initializeStoreAndPurchases(
    {required BuildContext context, required bool popRouteWithPurchase}) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  premiumPopupEnabled = false;
  return <String, ProductDetails>{};
}

Future restorePurchases(BuildContext context) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
}

showHelpRestorePopup(BuildContext context) {}

bool hidePremiumPopup() {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  return true;
}

Future<bool> premiumPopupPushRoute(BuildContext context) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  return true;
}

Future<bool> premiumPopupBudgets(BuildContext context) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  return true;
}

Future<bool> premiumPopupObjectives(BuildContext context,
    {required ObjectiveType objectiveType}) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  return true;
}

Future<bool> premiumPopupPastBudgets(BuildContext context) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  return true;
}

Future premiumPopupAddTransaction(BuildContext context) async {
  appStateSettings["purchaseID"] = productIDs["lifetime"];
  return true;
}

class Products extends StatefulWidget {
  const Products({this.popRouteWithPurchase = false, super.key});
  final bool popRouteWithPurchase;

  @override
  State<Products> createState() => ProductsState();
}

class ProductsState extends State<Products> {
  void refreshState() {}
  void highlightProducts() {}

  @override
  Widget build(BuildContext context) {
    return const ManageSubscription();
  }
}

class SubscriptionFeature extends StatelessWidget {
  const SubscriptionFeature({
    required this.iconData,
    required this.label,
    this.description,
    super.key,
  });
  final IconData iconData;
  final String label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class SubscriptionOption extends StatelessWidget {
  const SubscriptionOption({
    required this.label,
    required this.price,
    this.originalPrice,
    required this.onTap,
    this.extraPadding,
    super.key,
  });
  final String label;
  final String price;
  final String? originalPrice;
  final VoidCallback onTap;
  final EdgeInsetsDirectional? extraPadding;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class LockedFeature extends StatelessWidget {
  const LockedFeature(
      {required this.child, this.actionAfter, this.showLock = false, Key? key})
      : super(key: key);
  final Widget child;
  final Function? actionAfter;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class FadeOutAndLockFeature extends StatefulWidget {
  const FadeOutAndLockFeature({
    required this.child,
    this.actionAfter,
    this.hasInitiallyDismissed = false,
    this.fadeOutQuick = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? actionAfter;
  final bool hasInitiallyDismissed;
  final bool fadeOutQuick;

  @override
  State<FadeOutAndLockFeature> createState() => _FadeOutAndLockFeatureState();
}

class _FadeOutAndLockFeatureState extends State<FadeOutAndLockFeature> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class PremiumBackground extends StatelessWidget {
  const PremiumBackground(
      {this.disableAnimation = false, this.purchased = true, super.key});
  final bool disableAnimation;
  final bool purchased;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class PremiumBanner extends StatelessWidget {
  const PremiumBanner({super.key});

  @override
  Widget build(BuildContext context) {
    appStateSettings["purchaseID"] = productIDs["lifetime"];
    return const SizedBox.shrink();
  }
}
