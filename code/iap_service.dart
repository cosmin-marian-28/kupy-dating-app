import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

/// Product IDs — must match App Store Connect / Google Play Console.
class IapIds {
  static const kupyHeart1 = 'love_bomb_1';
  static const kupyHeart3 = 'love_bomb_3';
  static const kupyHeart5 = 'love_bomb_5';
  static const cupidonArrow = 'cupidon_arrow_monthly';
  static const cupidonBlessing = 'cupidon_blessing_monthly';

  static const all = {kupyHeart1, kupyHeart3, kupyHeart5, cupidonArrow, cupidonBlessing};

  static const kupyCounts = {
    kupyHeart1: 1,
    kupyHeart3: 3,
    kupyHeart5: 5,
  };

  /// Mini hearts granted with each pack.
  static const miniHearts = {
    kupyHeart1: 500,
    kupyHeart3: 1500,
    kupyHeart5: 2500,
  };

  static const subTiers = {
    cupidonArrow: 'cracked_cupidon',
    cupidonBlessing: 'cupidons_blessing',
  };
}

class IapService {
  static final _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static Map<String, ProductDetails> products = {};
  static bool available = false;

  /// Call once at app start.
  static Future<void> init() async {
    try {
      available = await _iap.isAvailable();
      debugPrint('[IAP] available: $available');
    } catch (e) {
      debugPrint('[IAP] not supported on this platform: $e');
      available = false;
      return;
    }
    if (!available) {
      debugPrint('[IAP] Store not available');
      return;
    }

    // Load product details from store
    final response = await _iap.queryProductDetails(IapIds.all);
    debugPrint('[IAP] queried ${IapIds.all.length} products');
    if (response.error != null) {
      debugPrint('[IAP] query error: ${response.error!.message}');
    }
    debugPrint('[IAP] found ${response.productDetails.length} products');
    debugPrint('[IAP] not found: ${response.notFoundIDs}');
    for (final p in response.productDetails) {
      products[p.id] = p;
      debugPrint('[IAP] product: ${p.id} — ${p.price}');
    }

    // Listen for purchase updates
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (e) {
      debugPrint('[IAP] stream error: $e');
    });
  }

  static void dispose() {
    _sub?.cancel();
  }

  /// Buy a product by its ID.
  static Future<bool> buy(String productId) async {
    final product = products[productId];
    debugPrint('[IAP] buy: $productId — product found: ${product != null}');
    if (product == null) {
      debugPrint('[IAP] product not found. Available: ${products.keys.toList()}');
      return false;
    }

    final isSubscription = IapIds.subTiers.containsKey(productId);
    final param = PurchaseParam(productDetails: product);

    try {
      if (isSubscription) {
        debugPrint('[IAP] buying subscription...');
        return await _iap.buyNonConsumable(purchaseParam: param);
      } else {
        debugPrint('[IAP] buying consumable...');
        return await _iap.buyConsumable(purchaseParam: param);
      }
    } catch (e) {
      debugPrint('[IAP] buy error: $e');
      return false;
    }
  }

  /// Get the store price string for a product (e.g. "5,00 RON").
  /// Falls back to null if product not loaded yet.
  static String? priceOf(String productId) {
    return products[productId]?.price;
  }

  static const _deliveredKey = 'iap_delivered_transactions';

  /// Returns the set of transaction IDs we've already fulfilled.
  static Future<Set<String>> _getDelivered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_deliveredKey)?.toSet() ?? {};
  }

  /// Marks a transaction ID as delivered so we never fulfill it twice.
  static Future<void> _markDelivered(String transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final delivered = prefs.getStringList(_deliveredKey)?.toList() ?? [];
    delivered.add(transactionId);
    // Keep only the last 200 to avoid unbounded growth
    if (delivered.length > 200) {
      delivered.removeRange(0, delivered.length - 200);
    }
    await prefs.setStringList(_deliveredKey, delivered);
  }

  static Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('[IAP] purchase update: ${purchase.productID} status=${purchase.status}');
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final txId = purchase.purchaseID ?? '';
        final delivered = await _getDelivered();
        if (txId.isNotEmpty && delivered.contains(txId)) {
          debugPrint('[IAP] already delivered txId=$txId — skipping');
        } else {
          await _deliverProduct(purchase);
          if (txId.isNotEmpty) await _markDelivered(txId);
        }
      }
      if (purchase.status == PurchaseStatus.error) {
        debugPrint('[IAP] purchase error: ${purchase.error?.message}');
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  static Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final id = purchase.productID;

    // Consumable — KupyHearts + mini hearts
    final kupyCount = IapIds.kupyCounts[id];
    if (kupyCount != null) {
      for (int i = 0; i < kupyCount; i++) {
        await SubscriptionService.buyBomb();
      }
      // Grant bonus mini hearts
      final hearts = IapIds.miniHearts[id];
      if (hearts != null) {
        await SubscriptionService.grantHearts(hearts);
      }
      return;
    }

    // Subscription
    final tier = IapIds.subTiers[id];
    if (tier != null) {
      // Check if user already has this active subscription (renewal)
      final currentTier = await SubscriptionService.currentTier();
      final isRenewal = currentTier == tier;

      // Always extend the subscription period
      await SubscriptionService.subscribe(tier);

      // Only grant perks on initial purchase, not renewals
      if (!isRenewal) {
        if (tier == 'cracked_cupidon') {
          // 1 KupyHeart + 5000 mini hearts
          await SubscriptionService.buyBomb();
          await SubscriptionService.grantHearts(5000);
        } else if (tier == 'cupidons_blessing') {
          // 5 KupyHearts + unlimited mini hearts
          for (int i = 0; i < 5; i++) {
            await SubscriptionService.buyBomb();
          }
          await SubscriptionService.grantUnlimitedHearts();
        }
      } else {
        debugPrint('[IAP] subscription renewal for $tier — extending expiry only');
      }
    }
  }

  /// Restore previous purchases (subscriptions).
  static Future<void> restore() async {
    await _iap.restorePurchases();
  }
}
