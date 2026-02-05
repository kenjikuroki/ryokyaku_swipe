import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseManager {
  static final PurchaseManager instance = PurchaseManager._internal();
  PurchaseManager._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  static const String productId = 'unlock_ryokaku';
  
  // Expose premium status
  final ValueNotifier<bool> isPremium = ValueNotifier(false);
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    // 1. Load local status first (fail-safe and speed)
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(productId) ?? false; // Default false

    // 2. Listen to purchase updates
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      debugPrint('Purchase Stream Error: $error');
    });
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase Pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
           
           if (purchaseDetails.productID == productId) {
             await _verifyAndDeliverProduct(purchaseDetails);
           }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }
  
  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    debugPrint('Purchase Verified: ${purchaseDetails.productID}');
    
    // Persist status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(productId, true);
    
    // Update notifier (triggers UI and AdManager updates)
    isPremium.value = true;
  }

  /// Initiates the purchase flow
  Future<void> buyPremium() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Store not available');
      return;
    }
    
    final Set<String> ids = {productId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    
    if (response.notFoundIDs.isNotEmpty) {
       debugPrint('Product not found: ${response.notFoundIDs}');
    }
    
    if (response.productDetails.isEmpty) {
      debugPrint('No product details found for $productId');
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Non-consumable
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }
  
  /// Restores purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
