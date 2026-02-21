import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class UpgradeService {
  static const String _proPlanId =
      'pro_plan'; // Replace with your actual product ID

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  final StreamController<List<PurchaseDetails>> _purchaseUpdatedController =
      StreamController.broadcast();
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseUpdatedController.stream;

  void listenToPurchaseUpdates(BuildContext context) {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      if (context.mounted) {
        _listenToPurchaseUpdated(purchaseDetailsList, context);
        _purchaseUpdatedController.add(purchaseDetailsList);
      }
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Handle error
    });
  }

  Future<List<ProductDetails>> getProducts() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      return [];
    }
    const Set<String> ids = <String>{_proPlanId};
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
      // Handle notFoundIDs
    }
    return response.productDetails;
  }

  Future<void> purchaseProPlan(
      ProductDetails productDetails, BuildContext context) async {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList, BuildContext context) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase is pending...')));
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Purchase Error: ${purchaseDetails.error?.message}')));
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase successful!')));
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _subscription.cancel();
    _purchaseUpdatedController.close();
  }
}
