// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '運行管理者 旅客';

  @override
  String get subTitle => 'スキマ時間でサクサク合格！一問一答';

  @override
  String get part1 => '道路運送法';

  @override
  String get part2 => '道路運送車両法';

  @override
  String get part3 => '道路交通法';

  @override
  String get part4 => '労働基準法 & 改善基準告示';

  @override
  String get part5 => '実務上の知識及び能力';

  @override
  String reviewWeakness(int count) {
    return '苦手を復習する ($count問)';
  }

  @override
  String get sisterAppTitle => '公式例題ベースの問題集アプリが登場！';

  @override
  String get sisterAppSubTitle => '「サクサク過去問」';

  @override
  String get premiumUpgrade => 'プレミアムアップグレード';

  @override
  String get premiumUpgradeDesc => '広告を完全に非表示にし、全問順番通りモードを解放！';

  @override
  String get buy => '購入';

  @override
  String get restore => '購入を復元する';

  @override
  String get shuffleMode => 'シャッフル';

  @override
  String get sequentialMode => '順番通り';

  @override
  String get lockedModeDesc => 'このモードはプレミアム限定です';

  @override
  String get categorySelect => 'カテゴリーを選択';

  @override
  String get allCategories => '全カテゴリー';

  @override
  String questionsCount(int count) {
    return '$count問';
  }

  @override
  String get feature1Title => '「連続」モードの解放';

  @override
  String get feature1Desc => '1問目から順番にすべての問題を解くことができます。';

  @override
  String get feature2Title => '広告を完全に非表示';

  @override
  String get feature2Desc => 'アプリ内のあらゆる広告（バナー、動画など）を非表示にします。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get startQuiz => '開始';

  @override
  String get undo => '元に戻す';

  @override
  String questionIndex(int index) {
    return '第$index問';
  }

  @override
  String get correct => '正解！ ⭕';

  @override
  String get incorrect => '不正解... ❌';

  @override
  String get passed => '合格圏内！素晴らしい！';

  @override
  String get failed => 'あと少し！復習しよう';

  @override
  String get perfect => 'PERFECT! 🎉';

  @override
  String overcomeWeakness(int count) {
    return '$count個の苦手を克服しました！';
  }

  @override
  String get checkMistakes => 'ミスを確認';

  @override
  String get imageQuestion => '画像問題';

  @override
  String get retry => 'リトライ';

  @override
  String get backToHome => 'ホームに戻る';

  @override
  String get sisterAppDialogTitle => '関連アプリもチェック！';

  @override
  String get sisterAppDialogBody => '別の資格試験対策アプリも公開中です。';

  @override
  String get open => '開く';

  @override
  String get back => '戻る';

  @override
  String get noData => '問題データがまだありません';

  @override
  String get selectCategory => 'カテゴリーを選択';

  @override
  String get purchase => '購入する';

  @override
  String get restorePurchase => '購入を復元する';

  @override
  String get featureSequentialTitle => '「連続」モードの解放';

  @override
  String get featureSequentialDesc => '1問目から順番にすべての問題を解くことができます。';

  @override
  String get featureNoAdsTitle => '広告を完全に非表示';

  @override
  String get featureNoAdsDesc => 'アプリ内のあらゆる広告を非表示にします。';

  @override
  String get premiumCardTitle => 'プレミアムプランに\nアップグレード';

  @override
  String get premiumCardSubtitle => '広告を非表示にして集中！';
}
