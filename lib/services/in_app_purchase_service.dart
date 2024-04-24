import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/mixins/subscription_mixin.dart';
import 'package:kendamanomics_mobile/models/tamas_group.dart';
import 'package:kendamanomics_mobile/services/persistent_data_service.dart';
import 'package:kiwi/kiwi.dart';

enum InAppPurchaseEvents { startedPurchase, purchased, failed }

class InAppPurchaseService with LoggerMixin, SubscriptionMixin<InAppPurchaseEvents> {
  final _persistentDataService = KiwiContainer().resolve<PersistentDataService>();
  final _inAppPurchaseInstance = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  late bool available;

  final _products = <ProductDetails>[];

  void init() async {
    available = await _inAppPurchaseInstance.isAvailable();

    final Stream<List<PurchaseDetails>> purchaseUpdates = InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdates.listen(_handlePurchaseUpdates);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> details) async {
    for (final detail in details) {
      switch (detail.status) {
        case PurchaseStatus.purchased:
          sendEvent(InAppPurchaseEvents.purchased, params: [TamasGroup.revertPaymentIdToId(detail.productID)]);
          try {
            await _inAppPurchaseInstance.completePurchase(detail);
          } catch (e) {
            logE('error completing purchase ${e.toString()}');
          }
          break;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          sendEvent(InAppPurchaseEvents.failed);
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.restored:
          break;
      }
    }
  }

  Future<void> purchasePremiumTamasGroup({required String premiumTamasGroupID}) async {
    final selectedProductDetails = _products.where((element) => element.id == premiumTamasGroupID).first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: selectedProductDetails);
    sendEvent(InAppPurchaseEvents.startedPurchase);
    await _inAppPurchaseInstance.buyConsumable(purchaseParam: purchaseParam);
  }

  void queryProducts() async {
    final premiumTamasGroupsIDs = _persistentDataService.premiumTamasGroupIDs.map((e) => e.replaceAll('-', '_')).toSet();
    final ProductDetailsResponse response = await _inAppPurchaseInstance.queryProductDetails(premiumTamasGroupsIDs);
    _products.clear();
    _products.addAll(response.productDetails);
  }

  void dispose() {
    _subscription.cancel();
  }

  @override
  String get className => 'InAppPurchaseService';
}
