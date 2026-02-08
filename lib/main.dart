// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ★ 追加：timezone 初期化用
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'screens/home_screen.dart';
import 'screens/pose_counter_screen.dart';
import 'screens/report_screen_js.dart' as report_js;
import 'screens/others_screen.dart';
import 'screens/settings_screen.dart';

// 顔認証（独立機能）スクリーン
import 'screens/face_auth_screen.dart';

// 身長/体重ストア
import 'services/bmi_store.dart';

// ガイド
import 'screens/guide_screen.dart';

// 週目標ストア＆設定画面
import 'services/weekly_goal_store.dart';
import 'screens/weekly_goal_screen.dart';

// トレーニング履歴
import 'services/workout_history_store.dart';
import 'screens/history_screen.dart';

// ★ 追加：時間制シンプルカウント用画面
import 'screens/simple_timer_workout_screen.dart';

// ★ リマインダーサービス
import 'services/reminder_service.dart';

// ★ 追加：音声コーチ（モチベーションTTS）
import 'services/voice_coach.dart';

import 'screens/tutorial_screens.dart';

import 'screens/beginner_routine_screen.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ タイムゾーン初期化（必須）
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  // 各ストア初期化
  await BmiStore.init();
  await WeeklyGoalStore.init();
  await WorkoutHistoryStore.init();

  // ★ リマインダー（ローカル通知）初期化
  await ReminderService.init();

  // ★ 音声コーチ初期化（TTS）
  await VoiceCoach.instance.init();

  runApp(const MyApp());
}

// ↓ ここから下はそのままでOK
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accentBlue = Color(0xFF2962FF);

    return MaterialApp(
      title: 'Home Workout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/report': (_) => const report_js.ReportScreen(),
        '/others': (_) => const OthersScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/face_auth': (_) => const FaceAuthScreen(),
        '/guide': (_) => const GuideScreen(),
        '/weekly_goal': (_) => const WeeklyGoalScreen(),
        '/history': (_) => const HistoryScreen(),
        // ★ 時間制シンプルカウント
        '/simple_timer': (_) => const SimpleTimerWorkoutScreen(),

        '/tutorial_welcome': (_) => const TutorialWelcomeScreen(),
        '/tutorial_camera': (_) => const TutorialCameraPositionScreen(),
        '/tutorial_skeleton': (_) => const TutorialSkeletonPreviewScreen(),
        '/tutorial_squat': (_) => const TutorialMiniSquatScreen(),
        '/tutorial_done': (_) => const TutorialFinishScreen(),
        '/beginner_menu': (_) => const BeginnerRoutinePreviewScreen(),
        
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/counter') {
          final args =
              (settings.arguments is Map) ? settings.arguments as Map : const {};
          return MaterialPageRoute(
            settings: RouteSettings(name: settings.name, arguments: args),
            builder: (_) => const OrientationHintWrapper(
              child: PoseCounterScreen(title: 'Counter'),
              hintText: 'カウント中は横向きでの利用を推奨します',
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}

/// 縦向きのときに「横向きで使ってください」バナーを重ねる（スマホは非表示）
class OrientationHintWrapper extends StatelessWidget {
  const OrientationHintWrapper({
    super.key,
    required this.child,
    this.hintText = '横向きで使ってください',
  });

  final Widget child;
  final String hintText;

  bool _isMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide < 600;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        final shouldShowBanner = !isMobile && isPortrait;

        return Stack(
          children: [
            child,
            if (shouldShowBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.screen_rotation,
                            color: Colors.black87),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hintText,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
