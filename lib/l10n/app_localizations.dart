import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'運行管理者 旅客'**
  String get appTitle;

  /// No description provided for @subTitle.
  ///
  /// In ja, this message translates to:
  /// **'スキマ時間でサクサク合格！一問一答'**
  String get subTitle;

  /// No description provided for @part1.
  ///
  /// In ja, this message translates to:
  /// **'道路運送法'**
  String get part1;

  /// No description provided for @part2.
  ///
  /// In ja, this message translates to:
  /// **'道路運送車両法'**
  String get part2;

  /// No description provided for @part3.
  ///
  /// In ja, this message translates to:
  /// **'道路交通法'**
  String get part3;

  /// No description provided for @part4.
  ///
  /// In ja, this message translates to:
  /// **'労働基準法 & 改善基準告示'**
  String get part4;

  /// No description provided for @part5.
  ///
  /// In ja, this message translates to:
  /// **'実務上の知識及び能力'**
  String get part5;

  /// No description provided for @reviewWeakness.
  ///
  /// In ja, this message translates to:
  /// **'苦手を復習する ({count}問)'**
  String reviewWeakness(int count);

  /// No description provided for @sisterAppTitle.
  ///
  /// In ja, this message translates to:
  /// **'４択問題アプリリリース！'**
  String get sisterAppTitle;

  /// No description provided for @sisterAppSubTitle.
  ///
  /// In ja, this message translates to:
  /// **'空き時間にサクサク解ける\n姉妹アプリはこちら'**
  String get sisterAppSubTitle;

  /// No description provided for @premiumUpgrade.
  ///
  /// In ja, this message translates to:
  /// **'プレミアムアップグレード'**
  String get premiumUpgrade;

  /// No description provided for @premiumUpgradeDesc.
  ///
  /// In ja, this message translates to:
  /// **'広告を完全に非表示にし、全問順番通りモードを解放！'**
  String get premiumUpgradeDesc;

  /// No description provided for @buy.
  ///
  /// In ja, this message translates to:
  /// **'購入'**
  String get buy;

  /// No description provided for @restore.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元する'**
  String get restore;

  /// No description provided for @shuffleMode.
  ///
  /// In ja, this message translates to:
  /// **'シャッフル'**
  String get shuffleMode;

  /// No description provided for @sequentialMode.
  ///
  /// In ja, this message translates to:
  /// **'順番通り'**
  String get sequentialMode;

  /// No description provided for @lockedModeDesc.
  ///
  /// In ja, this message translates to:
  /// **'このモードはプレミアム限定です'**
  String get lockedModeDesc;

  /// No description provided for @categorySelect.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリーを選択'**
  String get categorySelect;

  /// No description provided for @allCategories.
  ///
  /// In ja, this message translates to:
  /// **'全カテゴリー'**
  String get allCategories;

  /// No description provided for @questionsCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}問'**
  String questionsCount(int count);

  /// No description provided for @feature1Title.
  ///
  /// In ja, this message translates to:
  /// **'「連続」モードの解放'**
  String get feature1Title;

  /// No description provided for @feature1Desc.
  ///
  /// In ja, this message translates to:
  /// **'1問目から順番にすべての問題を解くことができます。'**
  String get feature1Desc;

  /// No description provided for @feature2Title.
  ///
  /// In ja, this message translates to:
  /// **'広告を完全に非表示'**
  String get feature2Title;

  /// No description provided for @feature2Desc.
  ///
  /// In ja, this message translates to:
  /// **'アプリ内のあらゆる広告（バナー、動画など）を非表示にします。'**
  String get feature2Desc;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @startQuiz.
  ///
  /// In ja, this message translates to:
  /// **'開始'**
  String get startQuiz;

  /// No description provided for @undo.
  ///
  /// In ja, this message translates to:
  /// **'元に戻す'**
  String get undo;

  /// No description provided for @questionIndex.
  ///
  /// In ja, this message translates to:
  /// **'第{index}問'**
  String questionIndex(int index);

  /// No description provided for @correct.
  ///
  /// In ja, this message translates to:
  /// **'正解！ ⭕'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In ja, this message translates to:
  /// **'不正解... ❌'**
  String get incorrect;

  /// No description provided for @passed.
  ///
  /// In ja, this message translates to:
  /// **'合格圏内！素晴らしい！'**
  String get passed;

  /// No description provided for @failed.
  ///
  /// In ja, this message translates to:
  /// **'あと少し！復習しよう'**
  String get failed;

  /// No description provided for @perfect.
  ///
  /// In ja, this message translates to:
  /// **'PERFECT! 🎉'**
  String get perfect;

  /// No description provided for @overcomeWeakness.
  ///
  /// In ja, this message translates to:
  /// **'{count}個の苦手を克服しました！'**
  String overcomeWeakness(int count);

  /// No description provided for @checkMistakes.
  ///
  /// In ja, this message translates to:
  /// **'ミスを確認'**
  String get checkMistakes;

  /// No description provided for @imageQuestion.
  ///
  /// In ja, this message translates to:
  /// **'画像問題'**
  String get imageQuestion;

  /// No description provided for @retry.
  ///
  /// In ja, this message translates to:
  /// **'リトライ'**
  String get retry;

  /// No description provided for @backToHome.
  ///
  /// In ja, this message translates to:
  /// **'ホームに戻る'**
  String get backToHome;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
