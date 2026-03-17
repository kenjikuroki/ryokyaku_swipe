// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Transport Manager (Pax)';

  @override
  String get subTitle => 'Pass in your spare time! Q&A';

  @override
  String get part1 => 'Road Transport Law';

  @override
  String get part2 => 'Road Transport Vehicle Law';

  @override
  String get part3 => 'Road Traffic Act';

  @override
  String get part4 => 'Labor Standards Act';

  @override
  String get part5 => 'Practical Knowledge & Ability';

  @override
  String reviewWeakness(int count) {
    return 'Review Weakness ($count questions)';
  }

  @override
  String get sisterAppTitle => '4-Choice Quiz App Released!';

  @override
  String get sisterAppSubTitle =>
      'Solve quickly in your spare time\nSister app is here';

  @override
  String get premiumUpgrade => 'Premium Upgrade';

  @override
  String get premiumUpgradeDesc =>
      'Completely hide ads and unlock sequential mode!';

  @override
  String get buy => 'Buy';

  @override
  String get restore => 'Restore Purchase';

  @override
  String get shuffleMode => 'Shuffle';

  @override
  String get sequentialMode => 'In Order';

  @override
  String get lockedModeDesc => 'This mode is premium only';

  @override
  String get categorySelect => 'Select Category';

  @override
  String get allCategories => 'All Categories';

  @override
  String questionsCount(int count) {
    return '$count questions';
  }

  @override
  String get feature1Title => 'Sequential Mode Unlocked';

  @override
  String get feature1Desc => 'Solve all questions in order from the first one.';

  @override
  String get feature2Title => 'Completely Hide Ads';

  @override
  String get feature2Desc =>
      'Hides all ads (banners, videos, etc.) in the app.';

  @override
  String get cancel => 'Cancel';

  @override
  String get startQuiz => 'Start';

  @override
  String get undo => 'Undo';

  @override
  String questionIndex(int index) {
    return 'Q. $index';
  }

  @override
  String get correct => 'Correct! ⭕';

  @override
  String get incorrect => 'Incorrect... ❌';

  @override
  String get passed => 'Passing range! Great!';

  @override
  String get failed => 'Almost there! Let\'s review';

  @override
  String get perfect => 'PERFECT! 🎉';

  @override
  String overcomeWeakness(int count) {
    return 'Overcame $count weaknesses!';
  }

  @override
  String get checkMistakes => 'Check Mistakes';

  @override
  String get imageQuestion => 'Image Question';

  @override
  String get retry => 'Retry';

  @override
  String get backToHome => 'Back to Home';
}
