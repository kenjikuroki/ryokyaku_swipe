import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'package:in_app_review/in_app_review.dart';
import 'package:auto_size_text/auto_size_text.dart';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'widgets/ad_banner.dart';
import 'utils/ad_manager.dart';
import 'utils/purchase_manager.dart';
import 'utils/prefs_helper.dart';
import 'utils/responsive_helper.dart';
import 'utils/notification_service.dart';
import 'widgets/special_offer_dialog.dart';
import 'widgets/category_review_modal.dart';
import 'widgets/tutorial_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/premium_upgrade_dialog.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ryokyaku_swipe/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'theme/app_chrome.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await PurchaseManager.instance.initialize();
  await NotificationService.initialize();
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// 1. Data Models & Helpers
// -----------------------------------------------------------------------------

class Quiz {
  final String question;
  final bool isCorrect;
  final String explanation;
  final String? imagePath;

  Quiz({
    required this.question,
    required this.isCorrect,
    required this.explanation,
    this.imagePath,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      question: (json['question'] as String).replaceAll('\n', ''),
      isCorrect: json['isCorrect'] as bool,
      explanation: json['explanation'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}

// PrefsHelper は utils/prefs_helper.dart に移動

class QuizData {
  static Map<String, List<Quiz>> _data = {};

  static Future<void> load() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _data = {};
      jsonData.forEach((key, value) {
        if (value is List) {
          _data[key] = value.map((q) => Quiz.fromJson(q)).toList();
        }
      });
    } catch (e) {
      debugPrint("Error loading quiz data: $e");
      _data = {};
    }
  }

  static List<Quiz> get part1 => _data['part1'] ?? [];
  static List<Quiz> get part2 => _data['part2'] ?? [];
  static List<Quiz> get part3 => _data['part3'] ?? [];
  static List<Quiz> get part4 => _data['part4'] ?? [];
  static List<Quiz> get part5 => _data['part5'] ?? [];

  static List<Quiz> getQuizzesFromTexts(List<String> texts) {
    final allQuizzes = [
      ...part1,
      ...part2,
      ...part3,
      ...part4,
      ...part5,
    ];
    return allQuizzes.where((q) => texts.contains(q.question)).toList();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '運行管理者 旅客',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''),
        Locale('en', ''),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundTop,
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      navigatorObservers: [routeObserver],
      home: const HomePage(),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Home Page
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  int _weaknessCount = 0;
  bool _isLoading = true;
  Map<String, int> _categoryWeaknessCounts = {};
  Map<String, int> _categoryHighScores = {};
  Map<String, int> _categoryAccuracyRates = {};
  Map<String, int> _categoryAnsweredCounts = {};
  int _bookmarkCount = 0;
  Map<String, int> _categoryBookmarkCounts = {};
  int _totalAnsweredCount = 0;
  int _consecutiveDaysStreak = 0;
  final List<String> _categoryKeys = const ['part1', 'part2', 'part3', 'part4', 'part5'];
  bool _isSequentialMode = false;
  bool _notifEnabled = true;
  int _notifHour = 20;
  DateTime? _examDate;
  int _dailyGoalTarget = 30;
  int _todayAnsweredCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadUserData();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await QuizData.load();
    await _loadUserData();
    if (mounted) setState(() => _isLoading = false);

    // UI表示後に権限・広告・バックグラウンド処理
    _initPostDisplay();

    // 初回のみ試験日オンボーディングを表示
    final onboardingDone = await PrefsHelper.isExamOnboardingDone();
    if (!onboardingDone && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _showExamDateOnboarding();
    }
  }

  Future<void> _initPostDisplay() async {
    final status = await AppTrackingTransparency.requestTrackingAuthorization();
    debugPrint("ATT Status: $status");
    await NotificationService.requestPermission();
    await MobileAds.instance.initialize();
    AdManager.instance.preloadAd('home');

    final notifEnabled = await PrefsHelper.getNotifEnabled();
    final notifHour = await PrefsHelper.getNotifHour();
    if (mounted) setState(() { _notifEnabled = notifEnabled; _notifHour = notifHour; });
    await NotificationService.scheduleDailyReminder(
      enabled: notifEnabled,
      hour: notifHour,
    );
  }

  Future<void> _showExamDateOnboarding() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ExamDateOnboardingSheet(
        initialDate: _examDate,
        onDateSelected: (date) async {
          await PrefsHelper.setExamDate(date);
          await PrefsHelper.markExamOnboardingDone();
          if (mounted) setState(() => _examDate = date);
        },
      ),
    );
    await PrefsHelper.markExamOnboardingDone();
  }

  Future<void> _loadUserData() async {
    final weakList = await PrefsHelper.getWeakQuestions();
    final bookmarkList = await PrefsHelper.getBookmarkedQuestions();
    final totalAnswered = await PrefsHelper.getAnsweredCount();
    final consecutiveDays = await PrefsHelper.getConsecutiveDaysStreak();
    final notifEnabled = await PrefsHelper.getNotifEnabled();
    final notifHour = await PrefsHelper.getNotifHour();
    final examDate = await PrefsHelper.getExamDate();
    final dailyGoal = await PrefsHelper.getDailyGoal();
    final dailyHistory = await PrefsHelper.getDailyAnsweredHistory();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayCount = dailyHistory[todayKey] ?? 0;

    final weakCounts = <String, int>{};
    final bookmarkCounts = <String, int>{};
    final highScores = <String, int>{};
    final accuracyRates = <String, int>{};
    final answeredCounts = <String, int>{};

    for (final key in _categoryKeys) {
      final quizzes = _getQuizzesByKey(key);
      final questionTexts = quizzes.map((q) => q.question).toSet();

      weakCounts[key] = weakList.where((t) => questionTexts.contains(t)).length;
      bookmarkCounts[key] = bookmarkList.where((t) => questionTexts.contains(t)).length;
      highScores[key] = await PrefsHelper.getHighScore('highscore_$key');

      final answered = await PrefsHelper.getCategoryAnsweredCount(key);
      final correct = await PrefsHelper.getCategoryCorrectCount(key);
      accuracyRates[key] = answered > 0 ? ((correct / answered) * 100).round() : 0;
      answeredCounts[key] = answered;
    }

    if (mounted) {
      setState(() {
        _weaknessCount = weakList.length;
        _bookmarkCount = bookmarkCounts.values.fold(0, (sum, c) => sum + c);
        _totalAnsweredCount = totalAnswered;
        _todayAnsweredCount = todayCount;
        _consecutiveDaysStreak = consecutiveDays;
        _notifEnabled = notifEnabled;
        _notifHour = notifHour;
        _examDate = examDate;
        _dailyGoalTarget = dailyGoal;
        _categoryWeaknessCounts = weakCounts;
        _categoryBookmarkCounts = bookmarkCounts;
        _categoryHighScores = highScores;
        _categoryAccuracyRates = accuracyRates;
        _categoryAnsweredCounts = answeredCounts;
      });
    }
  }

  void _startQuiz(BuildContext context, List<Quiz> quizList, String categoryKey, {bool isSequential = false}) async {
    List<Quiz> questionsToUse = List<Quiz>.from(quizList);

    if (!isSequential) {
      questionsToUse.shuffle();
      if (questionsToUse.length > 10) {
        questionsToUse = questionsToUse.take(10).toList();
      }
    }

    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadAd('quiz');
    AdManager.instance.preloadInterstitial();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: questionsToUse,
          categoryKey: categoryKey,
          totalQuestions: questionsToUse.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  void _startWeaknessReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CategoryReviewModal(
        counts: _categoryWeaknessCounts,
        onCategorySelected: (categoryKey) => _startWeaknessReviewByCategory(context, categoryKey),
      ),
    );
  }

  void _startWeaknessReviewByCategory(BuildContext context, String categoryKey) async {
    final navigator = Navigator.of(context);
    final weakTexts = await PrefsHelper.getWeakQuestions();
    if (!mounted) return;
    if (weakTexts.isEmpty) return;

    List<Quiz> weakQuizzes = QuizData.getQuizzesFromTexts(weakTexts);

    if (categoryKey != 'all') {
      final filteredTexts = _getQuizzesByKey(categoryKey).map((q) => q.question).toSet();
      weakQuizzes = weakQuizzes.where((q) => filteredTexts.contains(q.question)).toList();
    }

    if (weakQuizzes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このカテゴリーの苦手問題はありません')),
        );
      }
      return;
    }

    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadAd('quiz');
    AdManager.instance.preloadInterstitial();

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: weakQuizzes,
          isWeaknessReview: true,
          totalQuestions: weakQuizzes.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  void _startBookmarkReview(BuildContext context) {
    final counts = <String, int>{
      'all': _bookmarkCount,
      for (final key in _categoryKeys) key: _categoryBookmarkCounts[key] ?? 0,
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CategoryReviewModal(
        counts: counts,
        onCategorySelected: (categoryKey) => _startBookmarkReviewByCategory(context, categoryKey),
      ),
    );
  }

  void _startBookmarkReviewByCategory(BuildContext context, String categoryKey) async {
    final navigator = Navigator.of(context);
    final bookmarkedTexts = await PrefsHelper.getBookmarkedQuestions();
    if (!mounted) return;
    if (bookmarkedTexts.isEmpty) return;

    List<Quiz> bookmarkedQuizzes = QuizData.getQuizzesFromTexts(bookmarkedTexts);

    if (categoryKey != 'all') {
      final filteredTexts = _getQuizzesByKey(categoryKey).map((q) => q.question).toSet();
      bookmarkedQuizzes = bookmarkedQuizzes.where((q) => filteredTexts.contains(q.question)).toList();
    }

    if (bookmarkedQuizzes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このカテゴリーのブックマークはありません')),
        );
      }
      return;
    }

    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadAd('quiz');
    AdManager.instance.preloadInterstitial();

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: bookmarkedQuizzes,
          totalQuestions: bookmarkedQuizzes.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  void _startQuizByCategory(BuildContext context, String partKey) {
    final quizzes = _getQuizzesByKey(partKey);
    if (quizzes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.failed)),
      );
      return;
    }
    _startQuiz(context, quizzes, partKey, isSequential: _isSequentialMode);
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => const PremiumUpgradeDialog(),
    );
  }

  Widget _buildDailyGoal() {
    final achieved = _todayAnsweredCount >= _dailyGoalTarget;
    final progress = (_todayAnsweredCount / _dailyGoalTarget).clamp(0.0, 1.0);
    final progressColor = achieved ? const Color(0xFF4CAF50) : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: achieved
            ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: achieved
              ? const Color(0xFF4CAF50).withValues(alpha: 0.35)
              : AppColors.line.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(achieved ? Icons.check_circle_rounded : Icons.today_rounded, size: 14, color: progressColor),
            const SizedBox(width: 6),
            Text('今日の目標', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: progressColor.withValues(alpha: 0.75))),
          ]),
          const SizedBox(height: 2),
          Text(
            achieved ? '$_dailyGoalTarget問 達成！' : '$_todayAnsweredCount / $_dailyGoalTarget問',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: progressColor),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.line.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamDateBanner() {
    if (_examDate == null) {
      return GestureDetector(
        onTap: _showSettingsSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.inkMuted),
                SizedBox(width: 6),
                Text('試験日', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
              ]),
              SizedBox(height: 4),
              Text('設定から登録', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(_examDate!.year, _examDate!.month, _examDate!.day);
    final daysLeft = exam.difference(today).inDays;
    final Color bannerColor;
    final Color textColor;
    final String countdownText;
    if (daysLeft < 0) {
      bannerColor = AppColors.line.withValues(alpha: 0.4);
      textColor = AppColors.inkMuted;
      countdownText = '試験日が過ぎました';
    } else if (daysLeft == 0) {
      bannerColor = const Color(0xFFCC6A43).withValues(alpha: 0.12);
      textColor = const Color(0xFFCC6A43);
      countdownText = '今日が試験日！';
    } else if (daysLeft <= 7) {
      bannerColor = const Color(0xFFCC6A43).withValues(alpha: 0.10);
      textColor = const Color(0xFFCC6A43);
      countdownText = 'あと $daysLeft 日';
    } else if (daysLeft <= 30) {
      bannerColor = const Color(0xFFFF9D0A).withValues(alpha: 0.10);
      textColor = const Color(0xFFE08800);
      countdownText = 'あと $daysLeft 日';
    } else {
      bannerColor = AppColors.accent.withValues(alpha: 0.08);
      textColor = AppColors.accent;
      countdownText = 'あと $daysLeft 日';
    }
    final examLabel = '${_examDate!.year}/${_examDate!.month.toString().padLeft(2, '0')}/${_examDate!.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(Icons.calendar_month_rounded, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text('試験まで', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.75))),
          ]),
          const SizedBox(height: 4),
          Text(countdownText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
          Text(examLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(
        notifEnabled: _notifEnabled,
        notifHour: _notifHour,
        dailyGoal: _dailyGoalTarget,
        examDate: _examDate,
        streak: _consecutiveDaysStreak,
        onChanged: ({int? goal, bool? notifEnabled, int? notifHour}) async {
          if (goal != null) await PrefsHelper.setDailyGoal(goal);
          if (notifEnabled != null) await PrefsHelper.setNotifEnabled(notifEnabled);
          if (notifHour != null) await PrefsHelper.setNotifHour(notifHour);
          final enabled = notifEnabled ?? _notifEnabled;
          final hour = notifHour ?? _notifHour;
          await NotificationService.scheduleDailyReminder(enabled: enabled, hour: hour);
          if (mounted) _loadUserData();
        },
        onExamDateChanged: (date) async {
          if (date != null) {
            await PrefsHelper.setExamDate(date);
          } else {
            await PrefsHelper.clearExamDate();
          }
          if (mounted) setState(() => _examDate = date);
        },
      ),
    );
  }

  List<Quiz> _getQuizzesByKey(String key) {
    switch (key) {
      case 'part1': return QuizData.part1;
      case 'part2': return QuizData.part2;
      case 'part3': return QuizData.part3;
      case 'part4': return QuizData.part4;
      case 'part5': return QuizData.part5;
      default: return [];
    }
  }

  String _getCategoryName(String key) {
    switch (key) {
      case 'part1': return '道路運送法';
      case 'part2': return '道路運送車両法';
      case 'part3': return '道路交通法';
      case 'part4': return '労働基準法 & 改善基準告示';
      case 'part5': return '実務上の知識及び能力';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = AppLocalizations.of(context)!;
    final isCompact = !ResponsiveHelper.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          l10n.appTitle,
          style: TextStyle(
            fontSize: ResponsiveHelper.respFontSize(context, 17),
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _showSettingsSheet,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackground(
        child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, isCompact ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Toggle
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildExamDateBanner()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDailyGoal()),
                ],
              ),
            ),
            const SizedBox(height: 8),

            _buildTopSelectors(),
            const SizedBox(height: 12),

            // Category List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _categoryKeys.length,
              itemBuilder: (ctx, idx) {
                final key = _categoryKeys[idx];
                final quizzes = _getQuizzesByKey(key);
                return _CategoryListItem(
                  index: idx,
                  title: _getCategoryName(key),
                  questionCount: quizzes.length,
                  onTap: () => _startQuizByCategory(context, key),
                  onInfo: () => _showCategoryInfoSheet(context, key),
                );
              },
            ),
            const SizedBox(height: 8),

            // Bottom Actions: Weakness + Bookmark
            _buildBottomHomeActions(context, compact: isCompact),
            const SizedBox(height: 8),

            // Sister App
            ValueListenableBuilder<bool>(
              valueListenable: PurchaseManager.instance.isPremium,
              builder: (context, isPremium, child) {
                if (isPremium) return const SizedBox.shrink();
                return Column(
                  children: [
                    Card(
                      elevation: 4,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: InkWell(
                        onTap: () => _showSisterAppDialog(context),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.respPadding(context, 16.0), vertical: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/sakusaku_icon.png',
                                  width: ResponsiveHelper.respSize(context, 32),
                                  height: ResponsiveHelper.respSize(context, 32),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: ResponsiveHelper.respPadding(context, 10)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(l10n.sisterAppTitle,
                                        style: TextStyle(fontSize: ResponsiveHelper.respFontSize(context, 10), color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Text(l10n.sisterAppSubTitle,
                                        style: TextStyle(fontSize: ResponsiveHelper.respFontSize(context, 12), fontWeight: FontWeight.bold, height: 1.2)),
                                  ],
                                ),
                              ),
                              Icon(Icons.launch, color: Colors.grey, size: ResponsiveHelper.respIconSize(context, 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),

            _buildPremiumBanner(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTopSelectors() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ValueListenableBuilder<bool>(
        valueListenable: PurchaseManager.instance.isPremium,
        builder: (context, isPremium, _) {
          return Container(
            width: 90,
            height: 34,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
              boxShadow: AppChrome.softShadow,
            ),
            child: Row(
              children: [
                _buildModeTab(
                  icon: Icons.shuffle_rounded,
                  isSelected: !_isSequentialMode,
                  isLocked: false,
                  isFirst: true,
                  onTap: () => setState(() => _isSequentialMode = false),
                ),
                _buildModeTab(
                  icon: Icons.format_list_numbered_rounded,
                  isSelected: _isSequentialMode,
                  isLocked: !isPremium,
                  isFirst: false,
                  onTap: () {
                    if (!isPremium) {
                      _showPremiumDialog();
                      return;
                    }
                    setState(() => _isSequentialMode = true);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeTab({
    required IconData icon,
    required bool isSelected,
    required bool isLocked,
    required bool isFirst,
    required VoidCallback onTap,
  }) {
    final outerRadius = const Radius.circular(17);
    const innerRadius = Radius.zero;
    final borderRadius = isFirst
        ? BorderRadius.only(topLeft: outerRadius, bottomLeft: outerRadius, topRight: innerRadius, bottomRight: innerRadius)
        : BorderRadius.only(topRight: outerRadius, bottomRight: outerRadius, topLeft: innerRadius, bottomLeft: innerRadius);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.inkMuted),
              if (isLocked)
                Positioned(
                  right: 6,
                  bottom: 5,
                  child: Icon(Icons.lock_rounded, size: 9, color: isSelected ? Colors.white54 : AppColors.inkMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomHomeActions(BuildContext context, {bool compact = false}) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      foregroundColor: AppColors.ink,
      elevation: 2,
      shadowColor: const Color(0xFF21314D).withValues(alpha: 0.05),
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: compact ? 44 : 48,
            child: ElevatedButton.icon(
              onPressed: _weaknessCount > 0 ? () => _startWeaknessReview(context) : null,
              icon: const Icon(Icons.history_edu_rounded, color: Color(0xFFCC6A43)),
              label: Text('要復習 $_weaknessCount', style: const TextStyle(fontWeight: FontWeight.w800)),
              style: buttonStyle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: PurchaseManager.instance.isPremium,
            builder: (context, isPremium, child) {
              return SizedBox(
                height: compact ? 44 : 48,
                child: ElevatedButton.icon(
                  onPressed: _bookmarkCount > 0
                      ? () {
                          if (!isPremium) { _showPremiumDialog(); return; }
                          _startBookmarkReview(context);
                        }
                      : null,
                  icon: Icon(
                    isPremium ? Icons.bookmark_rounded : Icons.lock_rounded,
                    color: const Color(0xFF5D729D),
                  ),
                  label: Text('ブックマーク $_bookmarkCount', style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F6FB),
                    foregroundColor: AppColors.accent,
                    elevation: 2,
                    shadowColor: const Color(0xFF21314D).withValues(alpha: 0.05),
                    side: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSisterAppDialog(BuildContext context) {
    const urlString = 'https://apps.apple.com/jp/app/id6768983288';
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/sakusaku_icon.png', width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              const Text(
                'サクサク過去問',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                '公式例題ベースのスワイプ問題集アプリです。\nApp Storeで詳細を確認できます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final uri = Uri.parse(urlString);
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(l10n.open, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: PurchaseManager.instance.isPremium,
      builder: (context, isPremium, _) {
        if (isPremium) return const SizedBox.shrink();
        return GestureDetector(
          onTap: _showPremiumDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C4A7C), Color(0xFF4F6FA9)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C4A7C).withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD700),
                  size: 26,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'プレミアムにアップグレード',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '広告なし・連続モード・ブックマーク機能解放',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white60,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryInfoSheet(BuildContext context, String categoryKey) {
    final quizzes = _getQuizzesByKey(categoryKey);
    final questionCount = quizzes.length;
    final accuracyRate = _categoryAccuracyRates[categoryKey] ?? 0;
    final answeredCount = _categoryAnsweredCounts[categoryKey] ?? 0;
    final highScore = _categoryHighScores[categoryKey] ?? 0;
    final weaknessCount = _categoryWeaknessCounts[categoryKey] ?? 0;
    final completionRate = questionCount == 0
        ? 0.0
        : (math.min(answeredCount, questionCount) / questionCount).clamp(0.0, 1.0);
    final completionPercent = (completionRate * 100).round();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            gradient: LinearGradient(
              colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getCategoryName(categoryKey),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                SoftSurface(
                  borderRadius: BorderRadius.circular(22),
                  borderColor: AppColors.line.withValues(alpha: 0.84),
                  fillColor: Colors.white.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        _InfoSheetRow(
                          label: '問題数',
                          value: '$questionCount問',
                          icon: Icons.quiz_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 12),
                        _InfoSheetRow(
                          label: '正答率',
                          value: answeredCount > 0 ? '$accuracyRate%' : '未回答',
                          icon: Icons.percent_rounded,
                          color: accuracyRate >= 70
                              ? const Color(0xFF4CAF50)
                              : accuracyRate > 0
                                  ? const Color(0xFFFF9D0A)
                                  : AppColors.inkMuted,
                        ),
                        const SizedBox(height: 12),
                        _InfoSheetRow(
                          label: '回答数',
                          value: '$answeredCount問',
                          icon: Icons.bar_chart_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 12),
                        _InfoSheetRow(
                          label: '最高スコア',
                          value: highScore > 0 ? '$highScore点' : '--',
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFE08800),
                        ),
                        const SizedBox(height: 12),
                        _InfoSheetRow(
                          label: '要復習',
                          value: weaknessCount > 0 ? '$weaknessCount問' : 'なし',
                          icon: Icons.history_edu_rounded,
                          color: weaknessCount > 0
                              ? const Color(0xFFCC6A43)
                              : const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text(
                              '進捗',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              answeredCount == 0
                                  ? '未着手'
                                  : completionRate >= 1.0
                                      ? '完了'
                                      : '$completionPercent%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: completionRate >= 1.0
                                    ? const Color(0xFF4CAF50)
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: completionRate,
                            minHeight: 8,
                            backgroundColor: AppColors.line.withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completionRate >= 1.0
                                  ? const Color(0xFF4CAF50)
                                  : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

// ---------------------------------------------------------------------------
// Category list item (縦並びリスト用)
// ---------------------------------------------------------------------------

class _CategoryListItem extends StatelessWidget {
  static const _colors = [
    Color(0xFF4F6FA9),
    Color(0xFF4CAF50),
    Color(0xFFFF9D0A),
    Color(0xFFCC6A43),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
  ];

  final int index;
  final String title;
  final int questionCount;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const _CategoryListItem({
    required this.index,
    required this.title,
    required this.questionCount,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.75)),
          boxShadow: AppChrome.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.menu_book_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$questionCount問',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onInfo,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.inkMuted.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSheetRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoSheetRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSoft,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// 3. Quiz Page
// -----------------------------------------------------------------------------

class QuizPage extends StatefulWidget {
  final List<Quiz> quizzes;
  final String? categoryKey;
  final bool isWeaknessReview;
  final int totalQuestions;

  const QuizPage({
    super.key,
    required this.quizzes,
    this.categoryKey,
    this.isWeaknessReview = false,
    required this.totalQuestions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final AppinioSwiperController controller = AppinioSwiperController();

  int _score = 0;
  int _currentIndex = 1;
  final List<Quiz> _incorrectQuizzes = [];
  final List<Quiz> _correctQuizzesInReview = [];
  final List<Map<String, dynamic>> _answerHistory = [];
  int _currentCorrectStreak = 0;
  int _bestCorrectStreak = 0;
  Color _backgroundColor = Colors.transparent;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final shown = await PrefsHelper.isTutorialShown();
    if (!shown && mounted) setState(() => _showTutorial = true);
  }

  void _dismissTutorial() {
    setState(() => _showTutorial = false);
    PrefsHelper.markTutorialShown();
  }

  void _handleSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity) {
    if (activity is Swipe) {
      final quiz = widget.quizzes[previousIndex];
      bool userVal = (activity.direction == AxisDirection.right);
      bool isCorrect = (userVal == quiz.isCorrect);

      _answerHistory.add({
        'quiz': quiz,
        'result': isCorrect,
      });

      setState(() {
        if (isCorrect) {
          _score++;
          _currentCorrectStreak++;
          if (_currentCorrectStreak > _bestCorrectStreak) {
            _bestCorrectStreak = _currentCorrectStreak;
          }
          _backgroundColor = Colors.green.withValues(alpha: 0.2);
          HapticFeedback.lightImpact();

          if (widget.isWeaknessReview) {
            _correctQuizzesInReview.add(quiz);
          }
        } else {
          _currentCorrectStreak = 0;
          _backgroundColor = Colors.red.withValues(alpha: 0.2);
          _incorrectQuizzes.add(quiz);
          HapticFeedback.heavyImpact();
          _recordWeakness(quiz.question, false);
        }
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _backgroundColor = const Color(0xFFFFF3E0);
          });
        }
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text(
            isCorrect ? AppLocalizations.of(context)!.correct : AppLocalizations.of(context)!.incorrect,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.5,
            left: 50,
            right: 50,
          ),
        ),
      );

      setState(() {
        if (_currentIndex < widget.totalQuestions) {
          _currentIndex++;
        }
      });

      if (previousIndex == widget.quizzes.length - 1) {
        _finishQuiz();
      }
    }
  }

  Future<void> _recordWeakness(String question, bool isCorrect) async {
    if (isCorrect) {
      await PrefsHelper.removeWeakQuestions([question]);
    } else {
      await PrefsHelper.addWeakQuestions([question]);
    }
  }

  Future<void> _finishQuiz() async {
    await Future.delayed(const Duration(milliseconds: 700));

    if (widget.categoryKey != null) {
      await PrefsHelper.saveHighScore('highscore_${widget.categoryKey!}', _score);
      await PrefsHelper.addCategoryAnsweredCount(widget.categoryKey!, widget.quizzes.length);
      await PrefsHelper.addCategoryCorrectCount(widget.categoryKey!, _score);
    }
    await PrefsHelper.addAnsweredCount(widget.quizzes.length);
    await PrefsHelper.addDailyAnsweredCount(widget.quizzes.length);
    await PrefsHelper.saveBestStreak(_bestCorrectStreak);
    await PrefsHelper.saveDailyBestStreak(_bestCorrectStreak);

    if (_incorrectQuizzes.isNotEmpty) {
      final incorrectTexts = _incorrectQuizzes.map((q) => q.question).toList();
      await PrefsHelper.addWeakQuestions(incorrectTexts);
    }

    if (widget.isWeaknessReview && _correctQuizzesInReview.isNotEmpty) {
      final correctTexts = _correctQuizzesInReview.map((q) => q.question).toList();
      await PrefsHelper.removeWeakQuestions(correctTexts);
    }

    final completionCount = await PrefsHelper.incrementQuizCompletionCount();
    if (completionCount == 3) {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) inAppReview.requestReview();
    }

    if (mounted) {
      final shouldShow = await PrefsHelper.shouldShowInterstitial();

      if (shouldShow) {
        AdManager.instance.showInterstitial(
          onComplete: () async {
            if (mounted) {
              final bool showOffer = await SpecialOfferDialog.shouldShow();
              if (mounted && showOffer) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const SpecialOfferDialog(),
                );
                await SpecialOfferDialog.markAsShown();
              }
              if (mounted) _navigateToResult();
            }
          },
        );
      } else {
        _navigateToResult();
      }
    }
  }

  void _navigateToResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: widget.quizzes.length,
          history: _answerHistory,
          incorrectQuizzes: _incorrectQuizzes,
          originalQuizzes: widget.quizzes,
          categoryKey: widget.categoryKey,
          isWeaknessReview: widget.isWeaknessReview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: PurchaseManager.instance.isPremium,
          builder: (context, isPremium, child) {
            if (isPremium) return const SizedBox.shrink();
            return const SizedBox(
              height: 60,
              child: AdBanner(adKey: 'quiz', keepAlive: true),
            );
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: _backgroundColor,
            child: SafeArea(
              child: Column(
                children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.questionIndex(_currentIndex),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "$_currentIndex / ${widget.totalQuestions}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentIndex / widget.totalQuestions,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppinioSwiper(
                  controller: controller,
                  cardCount: widget.quizzes.length,
                  loop: false,
                  backgroundCardCount: 2,
                  swipeOptions: const SwipeOptions.symmetric(horizontal: true, vertical: false),
                  onSwipeEnd: _handleSwipeEnd,
                  cardBuilder: (context, index) {
                    return _buildCard(widget.quizzes[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        controller.unswipe();
                        setState(() {
                          if (_currentIndex > 1) {
                            _currentIndex--;
                          }
                          if (_answerHistory.isNotEmpty) {
                            final last = _answerHistory.removeLast();
                            final bool wasCorrect = last['result'];
                            final Quiz quiz = last['quiz'];
                            
                            if (wasCorrect) {
                              _score--;
                              if (widget.isWeaknessReview) {
                                _correctQuizzesInReview.remove(quiz);
                              }
                            } else {
                              _incorrectQuizzes.remove(quiz);
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.undo),
                      label: Text(AppLocalizations.of(context)!.undo),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ),
          ),
          if (_showTutorial)
            Positioned.fill(
              child: TutorialOverlay(onDismiss: _dismissTutorial),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Quiz quiz) {
    bool hasImage = quiz.imagePath != null;

    return SizedBox.expand(
      child: Container(
      margin: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          if (hasImage)
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: Image.asset(
                  quiz.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text("Image not found", style: TextStyle(color: Colors.grey[600])),
                      ],
                    );
                  },
                ),
              ),
            ),

          Expanded(
            flex: hasImage ? 5 : 10, // Maximize text area if no image
            child: Padding(
              padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start, // Top alignment
                        crossAxisAlignment: CrossAxisAlignment.stretch, // Allow mixed text alignment
                        // mainAxisSize: MainAxisSize.min, // Removed to allow Expanded child
                        children: [
                           if (!hasImage)
                            const Text(
                              "Q.",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                              textAlign: TextAlign.center, // Keep Q. centered
                            ),
                          if (!hasImage) const SizedBox(height: 20),

                          Expanded(
                            child: AutoSizeText(
                              quiz.question,
                              style: TextStyle(
                                fontSize: hasImage ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.left,
                              minFontSize: 12,
                              stepGranularity: 1,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 20, // Explicitly allow multiple lines
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(left: 40.0, right: 40.0, bottom: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => controller.swipeLeft(),
                  child: const Column(
                    children: [
                      Icon(Icons.close, color: Colors.redAccent, size: 48),
                      Text("誤り", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => controller.swipeRight(),
                  child: const Column(
                    children: [
                      Icon(Icons.circle_outlined, color: Colors.green, size: 48),
                      Text("正しい", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasImage) const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Result Page
// -----------------------------------------------------------------------------

class ResultPage extends StatefulWidget {
  final int score;
  final int total;
  final List<Map<String, dynamic>> history;
  final List<Quiz> incorrectQuizzes;
  final List<Quiz> originalQuizzes;
  final String? categoryKey;
  final bool isWeaknessReview;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.history,
    required this.incorrectQuizzes,
    required this.originalQuizzes,
    this.categoryKey,
    required this.isWeaknessReview,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Set<String> _bookmarkedQuestions = {};
  final ScrollController _scrollController = ScrollController();
  double _collapseProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    const collapseStart = 0.0;
    const collapseEnd = 80.0;
    final offset = _scrollController.offset.clamp(collapseStart, collapseEnd);
    final progress = (offset - collapseStart) / (collapseEnd - collapseStart);
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() => _collapseProgress = progress);
    }
  }

  Future<void> _loadBookmarks() async {
    final bookmarked = await PrefsHelper.getBookmarkedQuestions();
    if (!mounted) return;
    setState(() => _bookmarkedQuestions = bookmarked.toSet());
  }

  Future<void> _toggleBookmark(Quiz quiz) async {
    final isBookmarked = _bookmarkedQuestions.contains(quiz.question);
    if (isBookmarked) {
      await PrefsHelper.removeBookmarkedQuestions([quiz.question]);
    } else {
      await PrefsHelper.addBookmarkedQuestions([quiz.question]);
    }
    if (!mounted) return;
    setState(() {
      if (isBookmarked) _bookmarkedQuestions.remove(quiz.question);
      else _bookmarkedQuestions.add(quiz.question);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String scoreMessage;
    if (!widget.isWeaknessReview && widget.total >= 10) {
      scoreMessage = widget.score >= (widget.total * 0.8).floor() ? l10n.passed : l10n.failed;
    } else if (widget.isWeaknessReview && widget.score > 0) {
      scoreMessage = l10n.overcomeWeakness(widget.score);
    } else if (widget.score == widget.total) {
      scoreMessage = l10n.perfect;
    } else {
      scoreMessage = '';
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
        child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: PurchaseManager.instance.isPremium,
                  builder: (context, isUserPremium, child) {
                    if (isUserPremium) return const SizedBox.shrink();
                    return const AdBanner();
                  },
                ),
                _CollapsingResultSummary(
                  score: widget.score,
                  total: widget.total,
                  message: scoreMessage,
                  collapseProgress: _collapseProgress,
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.history.length,
                    itemBuilder: (context, index) {
                      final item = widget.history[index];
                      final Quiz quiz = item['quiz'];
                      final bool isCorrect = item['result'];
                      final bool isBookmarked = _bookmarkedQuestions.contains(quiz.question);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: isCorrect ? Colors.green : Colors.red,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          quiz.question,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (quiz.imagePath != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.image, size: 16, color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Text(AppLocalizations.of(context)!.imageQuestion, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _toggleBookmark(quiz),
                                    icon: Icon(
                                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                      color: isBookmarked ? Colors.amber[700] : Colors.grey[400],
                                    ),
                                    tooltip: isBookmarked ? 'ブックマーク解除' : 'ブックマーク',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "💡 ${quiz.explanation}",
                                  style: TextStyle(color: Colors.blueGrey[700], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (widget.incorrectQuizzes.isNotEmpty) ...[
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => QuizPage(
                                          quizzes: widget.incorrectQuizzes,
                                          isWeaknessReview: true,
                                          totalQuestions: widget.incorrectQuizzes.length,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(AppLocalizations.of(context)!.checkMistakes),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (widget.isWeaknessReview) {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                    return;
                                  }

                                  final shuffledAgain = List<Quiz>.from(widget.originalQuizzes)..shuffle();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => QuizPage(
                                        quizzes: shuffledAgain,
                                        categoryKey: widget.categoryKey,
                                        totalQuestions: shuffledAgain.length,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blueAccent,
                                  elevation: 0,
                                  side: const BorderSide(color: Colors.blueAccent, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                child: Text(widget.isWeaknessReview ? AppLocalizations.of(context)!.backToHome : AppLocalizations.of(context)!.retry),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!widget.isWeaknessReview)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: Text(
                              AppLocalizations.of(context)!.backToHome,
                              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      
                      // Removed bottom TextButton
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

// ─── Settings Sheet ──────────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final int dailyGoal;
  final bool notifEnabled;
  final int notifHour;
  final DateTime? examDate;
  final int streak;
  final void Function({int? goal, bool? notifEnabled, int? notifHour}) onChanged;
  final void Function(DateTime?) onExamDateChanged;

  const _SettingsSheet({
    required this.dailyGoal,
    required this.notifEnabled,
    required this.notifHour,
    required this.examDate,
    required this.streak,
    required this.onChanged,
    required this.onExamDateChanged,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late int _goal;
  late bool _notifEnabled;
  late int _notifHour;
  late DateTime? _examDate;

  static const _goalOptions = [10, 20, 30, 50, 70, 100];

  @override
  void initState() {
    super.initState();
    _goal = widget.dailyGoal;
    _notifEnabled = widget.notifEnabled;
    _notifHour = widget.notifHour;
    _examDate = widget.examDate;
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
      helpText: '試験日を選択',
    );
    if (picked == null) return;
    setState(() => _examDate = picked);
    widget.onExamDateChanged(picked);
  }

  Future<void> _clearExamDate() async {
    setState(() => _examDate = null);
    widget.onExamDateChanged(null);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: 0),
      helpText: '通知時間を選択',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _notifHour = picked.hour);
    widget.onChanged(notifHour: picked.hour);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 20),
            const Text('設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 20),

            // Exam Date
            const Text('試験日', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickExamDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line.withValues(alpha: 0.7))),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.inkMuted),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      _examDate != null
                          ? '${_examDate!.year}/${_examDate!.month.toString().padLeft(2, '0')}/${_examDate!.day.toString().padLeft(2, '0')}'
                          : '未設定',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _examDate != null ? AppColors.ink : AppColors.inkMuted),
                    )),
                    if (_examDate != null)
                      GestureDetector(
                        onTap: _clearExamDate,
                        child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.close_rounded, size: 18, color: AppColors.inkMuted)),
                      ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkMuted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.line.withValues(alpha: 0.5)),
            const SizedBox(height: 20),

            // Daily Goal
            const Text('今日の目標', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            Row(
              children: _goalOptions.map((g) {
                final selected = _goal == g;
                return Expanded(
                  child: GestureDetector(
                    onTap: () { setState(() => _goal = g); widget.onChanged(goal: g); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppColors.accent : AppColors.line.withValues(alpha: 0.8)),
                      ),
                      child: Column(children: [
                        Text('$g', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: selected ? Colors.white : AppColors.ink)),
                        Text('問', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? Colors.white.withValues(alpha: 0.8) : AppColors.inkMuted)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.line.withValues(alpha: 0.5)),
            const SizedBox(height: 20),

            // Notification
            const Text('学習リマインダー', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkMuted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line.withValues(alpha: 0.7))),
              child: Column(
                children: [
                  Row(children: [
                    const Icon(Icons.notifications_rounded, size: 18, color: AppColors.inkMuted),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('通知', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink))),
                    Switch.adaptive(value: _notifEnabled, activeColor: AppColors.accent, onChanged: (v) {
                      setState(() => _notifEnabled = v);
                      widget.onChanged(notifEnabled: v);
                    }),
                  ]),
                  if (_notifEnabled) ...[
                    Divider(height: 1, color: AppColors.line.withValues(alpha: 0.5)),
                    GestureDetector(
                      onTap: _pickTime,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: AppColors.inkMuted),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('通知時間', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink))),
                          Text('${_notifHour.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accent)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkMuted),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamDateOnboardingSheet extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const _ExamDateOnboardingSheet({required this.initialDate, required this.onDateSelected});

  @override
  State<_ExamDateOnboardingSheet> createState() => _ExamDateOnboardingSheetState();
}

class _ExamDateOnboardingSheetState extends State<_ExamDateOnboardingSheet> {
  DateTime? _selected;

  @override
  void initState() { super.initState(); _selected = widget.initialDate; }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: '試験日を選択',
    );
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(colors: [AppColors.backgroundTop, AppColors.backgroundBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 20),
            const Text('試験日を登録しよう', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 8),
            const Text('試験日を設定すると、ホーム画面に残り日数が表示されます。', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line.withValues(alpha: 0.7))),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.inkMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    _selected != null
                        ? '${_selected!.year}/${_selected!.month.toString().padLeft(2, '0')}/${_selected!.day.toString().padLeft(2, '0')}'
                        : '日付を選択',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _selected != null ? AppColors.ink : AppColors.inkMuted),
                  )),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkMuted),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selected != null ? () { widget.onDateSelected(_selected!); Navigator.pop(context); } : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('設定する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('あとで設定する', style: TextStyle(color: AppColors.inkMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Collapsing Result Summary Card ──────────────────────────────────────────

class _CollapsingResultSummary extends StatelessWidget {
  final int score;
  final int total;
  final String message;
  final double collapseProgress;

  const _CollapsingResultSummary({
    required this.score,
    required this.total,
    required this.message,
    required this.collapseProgress,
  });

  @override
  Widget build(BuildContext context) {
    final scoreFont = lerpDouble(48, 28, collapseProgress)!;
    final labelFont = lerpDouble(17, 14, collapseProgress)!;
    final horizontalPadding = lerpDouble(28, 20, collapseProgress)!;
    final verticalPadding = lerpDouble(20, 14, collapseProgress)!;
    final summaryHeight = lerpDouble(164, 80, collapseProgress)!;
    final borderRadius = lerpDouble(32, 20, collapseProgress)!;
    final messageOpacity = (1 - collapseProgress * 2.2).clamp(0.0, 1.0);

    return Container(
      height: summaryHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: double.infinity,
            maxWidth: ResponsiveHelper.respCardWidth(context) ?? double.infinity,
          ),
          child: SoftSurface(
            borderRadius: BorderRadius.circular(borderRadius),
            borderColor: AppColors.line.withValues(alpha: 0.78),
            fillColor: Colors.white.withValues(alpha: 0.98),
            child: ClipRect(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '正解数',
                          style: TextStyle(
                            fontSize: labelFont,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        SizedBox(width: lerpDouble(10, 8, collapseProgress)!),
                        Text(
                          '$score/$total',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.respFontSize(context, scoreFont),
                            fontWeight: FontWeight.w900,
                            color: AppColors.warning,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    if (collapseProgress < 0.5 && message.isNotEmpty) ...[
                      SizedBox(height: lerpDouble(10, 4, collapseProgress)!),
                      Opacity(
                        opacity: messageOpacity,
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: score == total
                                ? AppColors.success
                                : score >= (total * 0.8).floor()
                                    ? AppColors.success
                                    : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
