import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/purchase_manager.dart';

class SpecialOfferDialog extends StatelessWidget {
  const SpecialOfferDialog({super.key});

  static const String _prefKeyOfferShown = 'offer_shown_flag_v1';
  static final DateTime _limitDate = DateTime(2026, 3, 1);

  /// Checks if the offer should be shown.
  static Future<bool> shouldShow() async {
    // 1. Check Date
    if (DateTime.now().isAfter(_limitDate)) {
      return false;
    }

    // 2. Check Premium
    if (PurchaseManager.instance.isPremium.value) {
      return false;
    }

    // 3. Check if already shown
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_prefKeyOfferShown) ?? false;
    return !shown;
  }

  /// Marks the offer as shown to prevent future displays.
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyOfferShown, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             // Header Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0), // Light Orange
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars, size: 48, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            
            // Title
            const Text(
              "期間限定スペシャルオファー",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            const Text(
              "今すぐプレミアムにアップグレードして\n広告なしで快適に学習しませんか？",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            
            // Price Comparison
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "¥390",
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "¥190",
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Buy Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  PurchaseManager.instance.buyPremium();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  "今すぐ購入する",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Close Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "今回は見送る",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
