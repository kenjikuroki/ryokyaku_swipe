import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'purchase_manager.dart';

class PreloadedAd {
  final BannerAd ad;
  final ValueNotifier<bool> isLoaded = ValueNotifier(false);

  PreloadedAd(this.ad);

  void dispose() {
    ad.dispose();
    isLoaded.dispose();
  }
}

class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal() {
    PurchaseManager.instance.isPremium.addListener(() {
      if (PurchaseManager.instance.isPremium.value) {
        debugPrint('AdManager: Premium detected. Disposing all ads.');
        disposeAll();
      }
    });
  }

  final Map<String, PreloadedAd> _ads = {};

  /// 本番移行時（本番用の広告を表示する際）はここを `false` に変更してください。
  static const bool useTestAds = true;

  String get bannerAdUnitId {
    if (useTestAds) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Android Test ID
          : 'ca-app-pub-3940256099942544/2934735716'; // iOS Test ID
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3331079517737737/3315667975'
        : 'ca-app-pub-3331079517737737/5971312639';
  }

  void preloadAd(String key) {
    if (PurchaseManager.instance.isPremium.value) return;

    if (_ads.containsKey(key)) {
      // Already preloading or loaded
      return;
    }

    // Always use the real ID as requested by user, 
    // or switch to test ID if strictly debugging.
    // final unitId = kDebugMode ? _testAdUnitId : _adUnitId;
    final unitId = bannerAdUnitId;

    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Ad $key loaded.');
          _ads[key]?.isLoaded.value = true;
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdManager: Ad $key failed to load: $err');
          ad.dispose();
          _ads.remove(key);
        },
      ),
    );

    final preloadedAd = PreloadedAd(ad);
    _ads[key] = preloadedAd;
    ad.load();
  }

  PreloadedAd? getAd(String key) {
    return _ads[key];
  }
  
  /// Returns the ad and removes it from manager (transfer ownership)
  /// If [keep] is true, it retains in manager (shared ownership/singleton usage like Home).
  PreloadedAd? consumeAd(String key, {bool keep = false}) {
    if (keep) {
      return _ads[key];
    }
    return _ads.remove(key);
  }

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  
  // Real ID from user screenshot
  String get interstitialAdUnitId {
    if (useTestAds) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Android Test ID
          : 'ca-app-pub-3940256099942544/4411468910'; // iOS Test ID
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3331079517737737/5139739747'
        : 'ca-app-pub-3331079517737737/6031022389';
  }
  void preloadInterstitial() {
    // If already loaded or loading, skip? 
    // Simplified: just try to load if null.
    if (PurchaseManager.instance.isPremium.value) return;

    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId, 
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial loaded.');
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdManager: Interstitial failed to load: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Shows the interstitial ad if available.
  /// [onComplete] is called when the ad is dismissed or if it fails to show/load.
  void showInterstitial({required VoidCallback onComplete}) {
    if (_interstitialAd == null) {
      debugPrint('AdManager: No interstitial ready, skipping.');
      onComplete();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdManager: Interstitial dismissed.');
        ad.dispose();
        _interstitialAd = null;
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('AdManager: Interstitial failed to show: $err');
        ad.dispose();
        _interstitialAd = null;
        onComplete();
      },
    );

    _interstitialAd!.show();
    // Note: don't set null here immediately, wait for callbacks
  }
  
  void disposeAll() {
    for (var ad in _ads.values) {
      ad.dispose();
    }
    _ads.clear();
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
