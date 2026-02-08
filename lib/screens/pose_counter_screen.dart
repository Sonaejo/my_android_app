// lib/screens/pose_counter_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vmath;
import 'package:collection/collection.dart';

// ===== Web専用APIは条件付きインポート =====
// Webなら本物の dart:html / dart:js_util を使い、Android等ではスタブに切替
import '../web_stubs/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import '../web_stubs/jsutil_stub.dart'
    if (dart.library.html) 'dart:js_util' as jsutil;

// Android 用
import 'package:camera/camera.dart' as cam;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml;

// 設定
import 'package:shared_preferences/shared_preferences.dart';

// ★ 共通ロジックIF＋アダプタ
import '../logic/pose_logic.dart';
import '../logic/adapters/pushup_adapter.dart';
import '../logic/adapters/squat_adapter.dart';
import '../logic/adapters/crunch_adapter.dart';
import '../logic/adapters/plank_adapter.dart';

// アダプタの中で使う元ロジックをnewするためにインポート
import '../logic/pushup_logic.dart';
import '../logic/squat_logic.dart';
import '../logic/crunch_logic.dart';
import '../logic/plank_logic.dart';

// ★ 追加：被写体ロック（登録個人のみ通す）
import '../logic/subject_tracker.dart';

// ★ 追加：履歴・週目標・統計
import '../services/workout_history_store.dart';
import '../services/weekly_goal_store.dart';
import '../services/workout_stats_store.dart';

// ★ フォーム指示の音声読み上げ
import '../services/cue_speech_service.dart';

// ★ 追加：モチベーション用の音声コーチ（TTS）
import '../services/voice_coach.dart';

enum PoseMode { squat, pushup, crunch, plank }

// ★ Androidカメラの向き
enum AppCameraFacing { front, back }

// ─────────────────────────────────────────────
// チュートリアル用スクワット状態
// ─────────────────────────────────────────────
enum TutorialSquatPhase { standing, goingDown, bottom, goingUp }

class _TutorialSquatState {
  final TutorialSquatPhase phase;
  final int count;
  final bool completed;
  final String message;

  const _TutorialSquatState({
    required this.phase,
    this.count = 0,
    this.completed = false,
    this.message = '',
  });

  _TutorialSquatState copyWith({
    TutorialSquatPhase? phase,
    int? count,
    bool? completed,
    String? message,
  }) {
    return _TutorialSquatState(
      phase: phase ?? this.phase,
      count: count ?? this.count,
      completed: completed ?? this.completed,
      message: message ?? this.message,
    );
  }
}

class _CameraDistanceEval {
  final bool isOk;
  final double ratio;
  final String message;
  const _CameraDistanceEval({
    required this.isOk,
    required this.ratio,
    required this.message,
  });
}

class _ArmEval {
  final bool armUp;
  final double angle;
  final String message;
  const _ArmEval({
    required this.armUp,
    required this.angle,
    required this.message,
  });
}

class PoseCounterScreen extends StatefulWidget {
  const PoseCounterScreen({
    super.key,
    this.title = 'Counter',
    this.initialMode, // ← 直接渡したい場合に使える（ルート引数が優先）
  });

  final String title;
  final PoseMode? initialMode;

  @override
  State<PoseCounterScreen> createState() => _PoseCounterScreenState();
}

class _PoseCounterScreenState extends State<PoseCounterScreen> {
  // ---- モード ---------------------------------------------------------------
  PoseMode _mode = PoseMode.squat;
  bool _modeInitialized = false; // ルート引数読み取り & ロジック初期化を一度だけ

  // ---- 共通状態 ------------------------------------------------------------
  /// BlazePose準拠の 0..1 正規化ランドマーク（indexは33を想定。未提供は NaN）
  List<Offset> _landmarks = [];

  // ★ 追加：骨格線“描画用”の平滑化（チュートリアルと同じ狙い）
  List<Offset> _rawLandmarks = const []; // ロジック/ロック用（生）
  List<Offset>? _smoothDraw; // 描画用（平滑化）
  final List<_OneEuro2D?> _drawFilters = List<_OneEuro2D?>.filled(33, null);
  int? _drawLastUs;
  Timer? _drawHoldTimer;
  bool _drawHolding = false;

  // ジャンプ抑制のしきい値（0..1正規化）
  static const double _drawJumpTh = 0.15;

  // PoseLogic（アダプタ経由で統一）
  PoseLogic? _logic;
  PoseState _state = PoseState.empty;

  // ★ 被写体ロック
  final SubjectTracker _tracker = SubjectTracker();

  // ---- 設定値（/settings から読み込み） -----------------------------------
  bool _prefMirror = true; // ミラー表示（Androidのみ。WebはCSSで反転）
  String _prefCamera = 'front'; // 'front' | 'back'
  String _prefResolution = '720p'; // '720p' | '1080p'
  int _prefFps = 30; // 15〜60
  int _lastProcMs = 0; // FPS制限用

  // ---- Android -------------------------------------------------------------
  cam.CameraController? _camController;
  ml.PoseDetector? _poseDetector;
  bool _processing = false;

  // ★ 追加：Android カメラ向き & 一覧
  AppCameraFacing _currentFacing = AppCameraFacing.front;
  List<cam.CameraDescription>? _cameras;

  // ---- Web: イベントリスナー参照（解除用に保持） --------------------------
  html.EventListener? _poseListener;
  html.EventListener? _errorListener;

  // ★ Web権限拒否UI（連打防止）
  bool _webPermissionDenied = false;
  String _webPermissionMsg = 'カメラ権限が拒否されています。ブラウザの設定から許可してください。';
  int _webLastErrMs = 0;

  // ==== 実効FPS表示（共通） ===============================================
  final _FpsMeter _fpsMeter = _FpsMeter(); // 直近1秒の処理FPS
  String _fpsText = '— FPS';
  int _lastHudFpsMs = 0; // HUD更新の間引き（250msごと）

  // ==== テスト用オフセット ===============================================
  int _testRepsOffset = 0; // 表示上の回数オフセット
  double? _testKcalOverride; // 表示上のカロリー上書き（nullなら実測）

  // ==== フォーム指示 音声ガイド ===========================================
  /// 最後に読み上げた指示（同じ文の連続再生を防ぐ）
  String _lastSpokenCue = '';

  /// 音声ガイドON/OFF（設定画面と連携） … フォーム指示 + モチベ声掛け兼用
  bool _voiceGuideEnabled = true;

  // ★ 追加：モチベーション音声が「開始時に1回だけ」出たかどうか
  bool _motivationStarted = false;

  // 設定キー（SettingsScreen と同じキー名を使用）
  static const String _kVoiceGuidePref = 'voice_guide_enabled';
  static const String _kDailyGoalPref = 'daily_goal_reps';

  // ★ 追加：設定画面で決めた「今日の目標回数」
  int? _dailyGoalReps; // null or <=0 の場合は「目標なし」扱い
  bool _dailyGoalAnnounced = false; // この画面のセッション中に1回だけアナウンス

  // ==== チュートリアル用フラグ ============================================
  /// 'camera' | 'skeleton' | 'squat' | null
  String? _tutorialPhase;

  bool _tutorialCameraOk = false;
  String _tutorialCameraMsg = '画面中央に全身が入るように立ってください';

  bool _tutorialArmUp = false;
  String _tutorialArmMsg =
      '右腕をゆっくり上げて、骨格ラインが一緒に動くのを確認してみましょう';

  _TutorialSquatState _tutorialSquatState =
      const _TutorialSquatState(phase: TutorialSquatPhase.standing);

  bool get _isTutorial => _tutorialPhase != null;

  // ★ 骨格線デザイン（必要なら設定保存も可能）
  SkeletonStyle _skeletonStyle = SkeletonStyle.neon;

  // Web側のイベント名（JSと一致させる）
  static const String _kEvtPose = 'pose';
  static const String _kEvtErr = 'pose_error';

  @override
  void initState() {
    super.initState();

    // ★ セッション開始時にボイス状態をリセット（安全のため）
    VoiceCoach.instance.resetSession();
    _dailyGoalAnnounced = false;

    _loadPrefs().then((_) {
      if (kIsWeb) {
        _initWebBridge();
      } else {
        _initAndroidPipeline();
      }
    });
  }

  // ★ モードとロジックの初期化を1回だけ行う（buildの最初で呼ばれる）
  void _ensureModeInitialized(BuildContext context) {
    if (_modeInitialized) return;

    // 1) ルート引数を最優先（どんなMapでもOKに変換）
    final Object? rawArgs = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic> args = const {};
    if (rawArgs is Map) {
      args = rawArgs.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    final modeStr = (args['mode'] as String?)?.toLowerCase();
    if (modeStr == 'pushup') {
      _mode = PoseMode.pushup;
    } else if (modeStr == 'squat') {
      _mode = PoseMode.squat;
    } else if (modeStr == 'crunch') {
      _mode = PoseMode.crunch;
    } else if (modeStr == 'plank') {
      _mode = PoseMode.plank;
    } else if (widget.initialMode != null) {
      // 2) 明示コンストラクタ引数（任意）
      _mode = widget.initialMode!;
    }
    // 3) どれも無ければ既定: squat

    // ★ チュートリアルフェーズ（任意）
    final stepStr = (args['tutorialPhase'] as String?)?.toLowerCase();
    if (stepStr == 'camera' || stepStr == 'skeleton' || stepStr == 'squat') {
      _tutorialPhase = stepStr;
    }

    // モード確定後にロジックを構築
    if (_isTutorial) {
      // チュートリアル時は専用ロジックを使うので PoseLogic は使わない
      _logic = null;
      _state = PoseState.empty;
      _testRepsOffset = 0;
      _testKcalOverride = null;
    } else {
      if (_mode == PoseMode.pushup) {
        _logic = PushupAdapter(PushupLogic());
      } else if (_mode == PoseMode.crunch) {
        _logic = CrunchAdapter(CrunchLogic());
      } else if (_mode == PoseMode.plank) {
        _logic = PlankAdapter(PlankLogic());
      } else {
        _logic = SquatAdapter(SquatLogic());
      }
      _state = PoseState.empty;
      _testRepsOffset = 0;
      _testKcalOverride = null;
    }

    _modeInitialized = true;
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _prefMirror = p.getBool('mirror_preview') ?? true;
    _prefCamera = p.getString('camera_default') ?? 'front';
    _prefResolution = p.getString('resolution') ?? '720p';
    _prefFps = (p.getInt('fps_cap') ?? 30).clamp(15, 60);

    // ★ 追加：音声ガイドのON/OFFを設定から読み込む
    _voiceGuideEnabled = p.getBool(_kVoiceGuidePref) ?? true;

    // ★ 追加：今日の目標回数（設定画面から）
    _dailyGoalReps = p.getInt(_kDailyGoalPref);
    if (_dailyGoalReps != null && _dailyGoalReps! <= 0) {
      _dailyGoalReps = null;
    }

    // 🔽 デバッグログ
    debugPrint('[PREF] voice=$_voiceGuideEnabled dailyGoal=$_dailyGoalReps');

    // 読み込んだ設定から現在向きを一度だけ決定
    _currentFacing =
        (_prefCamera == 'back') ? AppCameraFacing.back : AppCameraFacing.front;

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _drawHoldTimer?.cancel();

    if (kIsWeb) {
      // リスナー解除 → Webカメラ/推論停止
      if (_poseListener != null) {
        html.window.removeEventListener(_kEvtPose, _poseListener!);
      }
      if (_errorListener != null) {
        html.window.removeEventListener(_kEvtErr, _errorListener!);
      }
      try {
        jsutil.callMethod(html.window, 'poseStop', const []);
      } catch (_) {}
    } else {
      _camController?.dispose();
      _poseDetector?.close();
    }

    _logic?.reset();
    cueSpeaker.stop();

    super.dispose();
  }

  // =========================== Web: CustomEvent bridge ======================
  void _initWebBridge() {
    // CustomEvent('pose', {detail:{landmarks:{...}}})
    _poseListener = (ev) {
      final e = ev as html.CustomEvent;
      final detail = e.detail;
      if (detail is Map && detail['landmarks'] != null) {
        final lm = _convertWebNamedToBlazeList(detail['landmarks']);
        // 推論が来た＝権限OKになったので拒否表示を消す
        if (_webPermissionDenied) {
          _webPermissionDenied = false;
          _webPermissionMsg = '';
        }
        _onNewLandmarks(lm);
      }
    };
    html.window.addEventListener(_kEvtPose, _poseListener!);

    // ✅ JS 側は "pose_error" を投げるので、それを購読する
    _errorListener = (ev) {
      final e = ev as html.CustomEvent;

      String msg = 'unknown error';
      String? code;
      String? name;

      if (e.detail is Map) {
        final d = e.detail as Map;
        msg = (d['message'] ?? 'unknown error').toString();

        // extra があれば拾う
        final extra = d['extra'];
        if (extra is Map) {
          code = extra['code']?.toString();
          name = extra['name']?.toString();
        } else {
          // 直接 code/name が入るケースも許容
          code = d['code']?.toString();
          name = d['name']?.toString();
        }
      }

      final lower = msg.toLowerCase();
      final isDenied = (code == 'permission_denied') ||
          (name == 'NotAllowedError') ||
          (name == 'PermissionDeniedError') ||
          lower.contains('notallowederror') ||
          lower.contains('permission') && lower.contains('denied');

      // 連打抑制（SnackBarは最大1秒に1回）
      final now = DateTime.now().millisecondsSinceEpoch;
      final allowSnack = (now - _webLastErrMs) > 1000;
      if (allowSnack) _webLastErrMs = now;

      if (!mounted) return;

      if (isDenied) {
        setState(() {
          _webPermissionDenied = true;
          _webPermissionMsg =
              'カメラ権限が拒否されています。\nブラウザのサイト設定でカメラを「許可」にしてください。\n（許可後にこの画面を再読み込み）';
        });
      } else {
        // 権限拒否以外は従来どおり通知（ただし連打しない）
        if (allowSnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Webカメラ/姿勢 読み込みエラー: $msg')),
          );
        }
      }
    };
    html.window.addEventListener(_kEvtErr, _errorListener!);

    // index.html 側の poseStart() を呼ぶ（Webのみ有効）
    try {
      jsutil.callMethod(html.window, 'poseStart', const []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('poseStart 呼び出しに失敗: $e')),
      );
    }
  }

  // =========================== Android: Camera + ML Kit =====================
  Future<void> _initAndroidPipeline() async {
    try {
      _cameras ??= await cam.availableCameras();
      final cameras = _cameras!;

      cam.CameraDescription pickByLens(cam.CameraLensDirection dir) =>
          cameras.firstWhere(
            (c) => c.lensDirection == dir,
            orElse: () => cameras.first,
          );

      // 現在の向きからカメラを選択
      final desiredDir = (_currentFacing == AppCameraFacing.back)
          ? cam.CameraLensDirection.back
          : cam.CameraLensDirection.front;

      final selected = pickByLens(desiredDir);

      final preset = (_prefResolution == '1080p')
          ? cam.ResolutionPreset.high
          : cam.ResolutionPreset.medium;

      _camController = cam.CameraController(
        selected,
        preset,
        enableAudio: false,
        imageFormatGroup: cam.ImageFormatGroup.nv21,
      );
      await _camController!.initialize();

      final options = ml.PoseDetectorOptions(
        mode: ml.PoseDetectionMode.stream,
        model: ml.PoseDetectionModel.base,
      );
      _poseDetector = ml.PoseDetector(options: options);

      _camController!.startImageStream((cam.CameraImage image) async {
        // FPS 上限（_prefFps）で間引き
        final now = DateTime.now().millisecondsSinceEpoch;
        final minIntervalMs = (1000 / _prefFps).floor();
        if (now - _lastProcMs < minIntervalMs) return;
        _lastProcMs = now;

        if (_processing) return;
        _processing = true;
        try {
          final cam.Plane plane = image.planes.first;
          final Uint8List bytes = plane.bytes;

          final ml.InputImageRotation rotation =
              _rotationFromController(_camController!);

          final ml.InputImage inputImage = ml.InputImage.fromBytes(
            bytes: bytes,
            metadata: ml.InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: rotation,
              format: ml.InputImageFormat.nv21,
              bytesPerRow: plane.bytesPerRow,
            ),
          );

          final poses = await _poseDetector!.processImage(inputImage);
          if (poses.isNotEmpty) {
            final pose = poses.first;

            double imageW = image.width.toDouble();
            double imageH = image.height.toDouble();
            if (rotation == ml.InputImageRotation.rotation90deg ||
                rotation == ml.InputImageRotation.rotation270deg) {
              final tmp = imageW;
              imageW = imageH;
              imageH = tmp;
            }

            final byType = pose.landmarks;
            Offset? getL(ml.PoseLandmarkType t) {
              final kp = byType[t];
              if (kp == null) return null;
              return Offset(kp.x / imageW, kp.y / imageH);
            }

            final list =
                List<Offset>.filled(33, const Offset(double.nan, double.nan));
            void put(int i, ml.PoseLandmarkType t) {
              final v = getL(t);
              if (v != null) list[i] = v;
            }

            put(11, ml.PoseLandmarkType.leftShoulder);
            put(12, ml.PoseLandmarkType.rightShoulder);
            put(13, ml.PoseLandmarkType.leftElbow);
            put(14, ml.PoseLandmarkType.rightElbow);
            put(15, ml.PoseLandmarkType.leftWrist);
            put(16, ml.PoseLandmarkType.rightWrist);
            put(23, ml.PoseLandmarkType.leftHip);
            put(24, ml.PoseLandmarkType.rightHip);
            put(25, ml.PoseLandmarkType.leftKnee);
            put(26, ml.PoseLandmarkType.rightKnee);
            put(27, ml.PoseLandmarkType.leftAnkle);
            put(28, ml.PoseLandmarkType.rightAnkle);

            _onNewLandmarks(list);
          } else {
            _onNewLandmarks(const []);
          }
        } catch (e) {
          // 必要なら print(e);
        } finally {
          _processing = false;
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('カメラ初期化に失敗: $e')),
      );
    }
  }

  // ★ カメラ切り替え（Android / Web 両対応）
  Future<void> _switchCamera() async {
    if (kIsWeb) {
      try {
        jsutil.callMethod(html.window, 'poseSwitchCamera', const []);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Webカメラ切替に失敗: $e')),
        );
      }
      return;
    }

    _currentFacing = (_currentFacing == AppCameraFacing.front)
        ? AppCameraFacing.back
        : AppCameraFacing.front;

    await _camController?.dispose();
    _camController = null;
    await _poseDetector?.close();
    _poseDetector = null;

    setState(() {});
    await _initAndroidPipeline();
  }

  // =============================== 骨格線用 平滑化（チュートリアル同等） =====
  double _calcDrawDtSec() {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    final last = _drawLastUs;
    _drawLastUs = nowUs;
    if (last == null) return 1.0 / 30.0;
    final dt = (nowUs - last) / 1e6;
    return dt.clamp(1.0 / 120.0, 1.0 / 10.0);
  }

  void _resetDrawFilters() {
    for (int i = 0; i < _drawFilters.length; i++) {
      _drawFilters[i] = null;
    }
    _smoothDraw = null;
    _drawLastUs = null;
  }

  bool _validLm(Offset p) => !(p.dx.isNaN || p.dy.isNaN);

  /// 骨格描画専用の平滑化（ロジックは“生”を使う）
  List<Offset> _smoothLandmarksForDraw(List<Offset> cur) {
    if (cur.isEmpty) {
      if (!_drawHolding && (_smoothDraw != null)) {
        _drawHolding = true;
        _drawHoldTimer?.cancel();
        _drawHoldTimer = Timer(const Duration(milliseconds: 150), () {
          _drawHolding = false;
          _resetDrawFilters();
          if (!mounted) return;
          setState(() => _landmarks = const []);
        });
      }
      return _smoothDraw ?? const [];
    }

    _drawHoldTimer?.cancel();
    _drawHolding = false;

    final dt = _calcDrawDtSec();

    _smoothDraw ??= List<Offset>.from(cur);
    final prev = _smoothDraw!;
    final out = List<Offset>.from(prev);

    for (int i = 0; i < cur.length && i < 33; i++) {
      final c = cur[i];
      if (!_validLm(c)) continue;

      final p = prev[i];

      _drawFilters[i] ??= _OneEuro2D(
        minCutoff: 2.2,
        beta: 0.08,
        dCutoff: 1.0,
      );

      if (_validLm(p)) {
        final dx = c.dx - p.dx;
        final dy = c.dy - p.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > _drawJumpTh) {
          final softened = Offset(
            p.dx + dx * 0.35,
            p.dy + dy * 0.35,
          );
          out[i] = _drawFilters[i]!.filter(softened, dt);
          continue;
        }
      }

      out[i] = _drawFilters[i]!.filter(c, dt);
    }

    _smoothDraw = out;
    return out;
  }

  // =============================== 共通処理 =================================
  void _onNewLandmarks(List<Offset> lm01) {
    if (!mounted) return;

    if (_voiceGuideEnabled && !_motivationStarted && lm01.isNotEmpty) {
      _motivationStarted = true;
      VoiceCoach.instance.onStart();
    }

    _fpsMeter.tick();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHudFpsMs >= 250) {
      _lastHudFpsMs = now;
      if (mounted) _fpsText = _fpsMeter.label;
    }

    if (_isTutorial) {
      _handleTutorialFrame(lm01);
      return;
    }

    final logic = _logic;
    if (logic == null) return;

    final filtered = _tracker.filter(lm01);
    if (_tracker.isLocked && filtered == null) {
      return;
    }
    final useLm = filtered ?? lm01;

    final int oldReps = _state.reps;
    final st = logic.process(PoseFrame(useLm, timestampMs: now));

    _handleCueSpeech(st.cues);

    final int newReps = st.reps;

    if (newReps > oldReps) {
      debugPrint('[REPS] old=$oldReps new=$newReps daily=$_dailyGoalReps');

      int goalReps = 0;
      bool useDailyGoal = false;
      final int? daily = _dailyGoalReps;

      if (daily != null && daily > 0) {
        goalReps = daily;
        useDailyGoal = true;
      } else {
        final double goalD =
            _pickMetricDouble(['goalReps', 'targetReps'], fallback: 0.0);
        goalReps = goalD.round();
      }

      for (int r = oldReps + 1; r <= newReps; r++) {
        VoiceCoach.instance.onRep(r);
      }

      if (goalReps > 0) {
        final int latest = newReps;
        final int remaining = goalReps - latest;

        if (remaining > 0 && remaining <= 3) {
          VoiceCoach.instance.onNearGoal(latest, goalReps);
        }

        if (useDailyGoal) {
          if (!_dailyGoalAnnounced && latest >= goalReps) {
            _dailyGoalAnnounced = true;

            debugPrint(
              '[DAILY GOAL] TRIGGER: latest=$latest goal=$goalReps '
              'old=$oldReps useDailyGoal=$useDailyGoal',
            );

            VoiceCoach.instance.onDailyGoalReached(goalReps);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('今日の目標 $goalReps 回を達成しました！'),
                ),
              );
            }
          }
        } else {
          if (latest >= goalReps && oldReps < goalReps) {
            debugPrint('[LOGIC GOAL] reached: latest=$latest goal=$goalReps');
            VoiceCoach.instance.onGoalReached(goalReps);
          }
        }
      }
    }

    final drawLm = _smoothLandmarksForDraw(useLm);

    if (!mounted) return;
    setState(() {
      _rawLandmarks = useLm;
      _landmarks = drawLm;
      _state = st;
    });

    if (!_isTutorial &&
        _dailyGoalReps != null &&
        _dailyGoalReps! > 0 &&
        !_dailyGoalAnnounced) {
      final int displayReps = _state.reps + _testRepsOffset;

      if (displayReps >= _dailyGoalReps!) {
        _dailyGoalAnnounced = true;

        debugPrint(
          '[DAILY GOAL][FALLBACK] displayReps=$displayReps '
          'goal=${_dailyGoalReps}',
        );

        VoiceCoach.instance.onDailyGoalReached(_dailyGoalReps!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('今日の目標 ${_dailyGoalReps!} 回を達成しました！'),
            ),
          );
        }
      }
    }
  }

  // ─────────────────────────────────────────────
  // チュートリアル 3 ステップ用フレーム処理
  // ─────────────────────────────────────────────
  void _handleTutorialFrame(List<Offset> lm01) {
    if (!mounted) return;

    List<String> cues = const [];

    if (_tutorialPhase == 'camera') {
      final res = _evalCameraDistance(lm01);
      cues = res.message.isNotEmpty ? [res.message] : const [];
      setState(() {
        _landmarks = lm01;
        _tutorialCameraOk = res.isOk;
        _tutorialCameraMsg = res.message;
      });
    } else if (_tutorialPhase == 'skeleton') {
      final res = _evalArmUp(lm01);
      cues = res.message.isNotEmpty ? [res.message] : const [];
      setState(() {
        _landmarks = lm01;
        _tutorialArmUp = res.armUp;
        _tutorialArmMsg = res.message;
      });
    } else if (_tutorialPhase == 'squat') {
      final prev = _tutorialSquatState;
      final next = _evalTutorialSquat(lm01, prev);

      if (_voiceGuideEnabled && next.count > prev.count) {
        for (int r = prev.count + 1; r <= next.count; r++) {
          VoiceCoach.instance.onRep(r);
        }
      }

      setState(() {
        _landmarks = lm01;
        _tutorialSquatState = next;
      });

      if (next.completed && !prev.completed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スクワットチュートリアル完了！')),
        );
      }

      cues = next.message.isNotEmpty ? [next.message] : const [];
    } else {
      setState(() {
        _landmarks = lm01;
      });
    }

    _handleCueSpeech(cues);
  }

  _CameraDistanceEval _evalCameraDistance(List<Offset> lm01) {
    final valid = lm01.where((p) => !p.dx.isNaN && !p.dy.isNaN).toList();
    if (valid.length < 4) {
      return const _CameraDistanceEval(
        isOk: false,
        ratio: 0,
        message: 'カメラに全身が映るように立ってください',
      );
    }

    double minY = 1.0;
    double maxY = 0.0;
    for (final p in valid) {
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final hRatio = (maxY - minY).clamp(0.0, 1.0);

    const minRatio = 0.30;
    const maxRatio = 0.60;

    if (hRatio < 0.15) {
      return const _CameraDistanceEval(
        isOk: false,
        ratio: 0.0,
        message: '少しカメラに近づいてください',
      );
    } else if (hRatio < minRatio) {
      return const _CameraDistanceEval(
        isOk: false,
        ratio: 0.0,
        message: 'もう少しカメラに近づいてみましょう',
      );
    } else if (hRatio > 0.8) {
      return const _CameraDistanceEval(
        isOk: false,
        ratio: 0.0,
        message: '近すぎます。カメラから少し離れてください',
      );
    } else if (hRatio > maxRatio) {
      return const _CameraDistanceEval(
        isOk: false,
        ratio: 0.0,
        message: '少しだけ後ろに下がってみましょう',
      );
    } else {
      return _CameraDistanceEval(
        isOk: true,
        ratio: hRatio,
        message: 'その距離でOKです！この状態をキープしてみましょう',
      );
    }
  }

  double _angleBetween(Offset a, Offset b, Offset c) {
    final v1 = vmath.Vector2(a.dx - b.dx, a.dy - b.dy);
    final v2 = vmath.Vector2(c.dx - b.dx, c.dy - b.dy);
    final dot = v1.dot(v2);
    final len = v1.length * v2.length;
    if (len == 0) return 0.0;
    var cosv = dot / len;
    cosv = cosv.clamp(-1.0, 1.0);
    return vmath.degrees(math.acos(cosv));
  }

  _ArmEval _evalArmUp(List<Offset> lm01) {
    Offset? get(int i) {
      if (i < 0 || i >= lm01.length) return null;
      final p = lm01[i];
      if (p.dx.isNaN || p.dy.isNaN) return null;
      return p;
    }

    final shoulder = get(12);
    final elbow = get(14);
    final wrist = get(16);

    if (shoulder == null || elbow == null || wrist == null) {
      return const _ArmEval(
        armUp: false,
        angle: 0,
        message: '右腕が画面に映る位置に立ってみましょう',
      );
    }

    final angle = _angleBetween(shoulder, elbow, wrist);
    const upThreshold = 140.0;

    if (angle >= upThreshold) {
      return _ArmEval(
        armUp: true,
        angle: angle,
        message: 'ナイス！腕を上げると骨格ラインも一緒に動きます',
      );
    } else {
      return _ArmEval(
        armUp: false,
        angle: angle,
        message: '右腕をゆっくり真上に上げてみましょう',
      );
    }
  }

  _TutorialSquatState _evalTutorialSquat(
    List<Offset> lm01,
    _TutorialSquatState prev,
  ) {
    Offset? get(int i) {
      if (i < 0 || i >= lm01.length) return null;
      final p = lm01[i];
      if (p.dx.isNaN || p.dy.isNaN) return null;
      return p;
    }

    final hip = get(24);
    final knee = get(26);
    final ankle = get(28);

    if (hip == null || knee == null || ankle == null) {
      return prev.copyWith(message: '正面を向いて全身が映るように立ってみましょう');
    }

    final kneeAngle = _kneeAngleDeg(hip, knee, ankle);
    const standThreshold = 160.0;
    const bottomThreshold = 100.0;

    var phase = prev.phase;
    var count = prev.count;
    var completed = prev.completed;
    var msg = prev.message;

    const targetReps = 5;

    switch (phase) {
      case TutorialSquatPhase.standing:
        msg = 'まっすぐ立った状態からスタートしましょう';
        if (kneeAngle < standThreshold) {
          phase = TutorialSquatPhase.goingDown;
          msg = 'ゆっくりしゃがんでいきましょう';
        }
        break;

      case TutorialSquatPhase.goingDown:
        msg = 'お尻を後ろに引くイメージでしゃがんでみましょう';
        if (kneeAngle < bottomThreshold) {
          phase = TutorialSquatPhase.bottom;
          msg = 'そこがボトムです。膝とつま先の向きをそろえましょう';
        } else if (kneeAngle > standThreshold + 5) {
          phase = TutorialSquatPhase.standing;
          msg = 'もう一度、立った姿勢からやってみましょう';
        }
        break;

      case TutorialSquatPhase.bottom:
        msg = 'その姿勢から、今度はゆっくり立ち上がりましょう';
        if (kneeAngle > bottomThreshold + 10) {
          phase = TutorialSquatPhase.goingUp;
        }
        break;

      case TutorialSquatPhase.goingUp:
        msg = '膝を伸ばして、まっすぐ立ち上がりましょう';
        if (kneeAngle > standThreshold) {
          count += 1;
          phase = TutorialSquatPhase.standing;
          if (count >= targetReps) {
            completed = true;
            msg = 'スクワット $count 回達成！チュートリアルクリアです';
          } else {
            final remain = targetReps - count;
            msg = 'いいですね！あと $remain 回やってみましょう';
          }
        }
        break;
    }

    return _TutorialSquatState(
      phase: phase,
      count: count,
      completed: completed,
      message: msg,
    );
  }

  void _handleCueSpeech(List<String> cues) {
    if (!_voiceGuideEnabled) return;
    if (cues.isEmpty) return;

    final text = cues.take(2).join('。');

    if (text.isEmpty) return;
    if (text == _lastSpokenCue) return;

    _lastSpokenCue = text;
    cueSpeaker.speak(text);
  }

  double _kneeAngleDeg(Offset hip, Offset knee, Offset ankle) {
    final v1 = vmath.Vector2(hip.dx - knee.dx, hip.dy - knee.dy);
    final v2 = vmath.Vector2(ankle.dx - knee.dx, ankle.dy - knee.dy);
    final dot = v1.dot(v2);
    final len = v1.length * v2.length;
    if (len == 0) return 180;
    final cosv = (dot / len).clamp(-1.0, 1.0);
    return vmath.degrees(math.acos(cosv));
  }

  String _fmtMMSS(double seconds) {
    final s = seconds.isFinite ? seconds.floor().clamp(0, 359999) : 0;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  double _calcTestKcal(int reps) {
    switch (_mode) {
      case PoseMode.pushup:
        return reps * 0.5;
      case PoseMode.squat:
        return reps * 0.7;
      case PoseMode.crunch:
        return reps * 0.4;
      case PoseMode.plank:
        return 0.0;
    }
  }

  void _onTestIncrement() {
    if (_isTutorial && _tutorialPhase == 'squat') {
      return;
    }

    setState(() {
      _testRepsOffset++;
      final dispReps = _state.reps + _testRepsOffset;
      _testKcalOverride = _calcTestKcal(dispReps);
    });

    if (_voiceGuideEnabled) {
      final int logicalReps = _state.reps + _testRepsOffset;
      VoiceCoach.instance.onRep(logicalReps);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureModeInitialized(context);

    final isSquat = _mode == PoseMode.squat;
    final isPushup = _mode == PoseMode.pushup;
    final isCrunch = _mode == PoseMode.crunch;

    final bool isTutorialSquat = _isTutorial && _tutorialPhase == 'squat';
    final bool isTutorialCamera = _isTutorial && _tutorialPhase == 'camera';
    final bool isTutorialSkeleton = _isTutorial && _tutorialPhase == 'skeleton';

    final int baseReps =
        isTutorialSquat ? _tutorialSquatState.count : _state.reps;
    final reps = baseReps + (_isTutorial ? 0 : _testRepsOffset);

    double baseProgress;
    if (isTutorialSquat) {
      const target = 5;
      baseProgress = (_tutorialSquatState.count / target).clamp(0.0, 1.0);
    } else {
      baseProgress = _state.progress;
    }
    final percent =
        '${(baseProgress * 100).clamp(0, 100).toStringAsFixed(0)}%';

    final postureDeg = _isTutorial
        ? 0.0
        : _pickMetricDouble([
            if (isSquat) 'torsoDeg',
            if (isPushup) 'bodySagDeg',
            if (isCrunch) ...['coreDeg', 'sagDeg', 'bodySagDeg'],
          ], fallback: 0.0);

    final elapsedSec =
        _isTutorial ? 0.0 : _pickMetricDouble(['elapsedSec'], fallback: 0.0);
    final baseKcal =
        _isTutorial ? 0.0 : _pickMetricDouble(['kcal'], fallback: 0.0);
    final kcal = _testKcalOverride ?? baseKcal;

    final posture = '${postureDeg.toStringAsFixed(0)}°';
    final timeStr = _fmtMMSS(elapsedSec);
    final kcalStr = '${kcal.toStringAsFixed(1)} kcal';

    final title = _isTutorial
        ? 'チュートリアル'
        : isSquat
            ? 'Squat Counter'
            : isPushup
                ? 'Push-up Counter'
                : isCrunch
                    ? 'Crunch Counter'
                    : 'Plank Timer';

    final postureLabel = isSquat ? '前傾' : '体幹';

    final cameraLabel = kIsWeb
        ? 'Web'
        : (_currentFacing == AppCameraFacing.front ? 'フロント' : 'バック');

    List<String> cuesToShow;
    if (isTutorialCamera) {
      cuesToShow = [_tutorialCameraMsg];
    } else if (isTutorialSkeleton) {
      cuesToShow = [_tutorialArmMsg];
    } else if (isTutorialSquat) {
      cuesToShow = [
        if (_tutorialSquatState.message.isNotEmpty) _tutorialSquatState.message
      ];
    } else {
      cuesToShow = _state.cues;
    }
    cuesToShow = cuesToShow.where((t) => t.trim().isNotEmpty).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: kIsWeb ? Colors.transparent : Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: kIsWeb
                    ? const ColoredBox(color: Colors.transparent)
                    : _buildAndroidCameraWithOverlay(),
              ),

              // ✅ Web: 権限拒否オーバーレイ（ここが今回の追加）
              if (kIsWeb && _webPermissionDenied)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.72),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DefaultTextStyle(
                          style: const TextStyle(color: Colors.white),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'カメラ権限が必要です',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _webPermissionMsg,
                                style: const TextStyle(height: 1.35),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton(
                                    onPressed: () {
                                      // 許可に変えたあと用：再読み込み
                                      try {
                                        html.window.location.reload();
                                      } catch (_) {}
                                    },
                                    child: const Text('再読み込み'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      // 一応、JS側に再要求APIがあれば叩く（無くてもOK）
                                      try {
                                        jsutil.callMethod(
                                            html.window, 'poseRequestPermission', const []);
                                      } catch (_) {}
                                      // ついでに start も試す
                                      try {
                                        jsutil.callMethod(html.window, 'poseStart', const []);
                                      } catch (_) {}
                                    },
                                    child: const Text('もう一度試す'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // メニューへ戻る
                                      Navigator.popUntil(context, ModalRoute.withName('/'));
                                    },
                                    child: const Text('戻る'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () {
                    if (_rawLandmarks.isNotEmpty) {
                      final ok = _tracker.enroll(_rawLandmarks);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text(ok ? '被写体をロックしました' : 'ロックに失敗（姿勢未検出）'),
                        ),
                      );
                      setState(() {});
                    }
                  },
                  onDoubleTap: () {
                    final wasLocked = _tracker.isLocked;
                    _tracker.clear();
                    if (wasLocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ロック解除')),
                      );
                    }
                    setState(() {});
                  },
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: kIsWeb
                      ? CustomPaint(
                          painter: _SkeletonPainter(
                            _landmarks,
                            mirrorX: true,
                            style: _skeletonStyle,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              Positioned(
                left: 12,
                top: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chip('回数', '$reps'),
                    const SizedBox(height: 6),
                    _chip(postureLabel, posture),
                    const SizedBox(height: 6),
                    _chip('時間', timeStr),
                    const SizedBox(height: 6),
                    _chip('カロリー', kcalStr),
                  ],
                ),
              ),

              Positioned(
                right: 12,
                top: 12,
                child: _chip('FPS', _fpsText),
              ),

              if (cuesToShow.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 80,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        cuesToShow.take(3).map((t) => _cueBadge(t)).toList(),
                  ),
                ),

              Positioned(
                right: 12,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: TextButton(
                    onPressed: () async {
                      if (_isTutorial) {
                        if (mounted) {
                          Navigator.popUntil(
                            context,
                            ModalRoute.withName('/'),
                          );
                        }
                        return;
                      }

                      final secReal =
                          _pickMetricDouble(['elapsedSec'], fallback: 0.0);
                      final repsReal = _state.reps + _testRepsOffset;

                      double kcalReal =
                          _pickMetricDouble(['kcal'], fallback: 0.0);

                      if (kcalReal <= 0 && repsReal > 0) {
                        kcalReal = _calcTestKcal(repsReal);
                      }

                      await WorkoutHistoryStore.addEntry(
                        WorkoutHistoryEntry(
                          ts: DateTime.now().millisecondsSinceEpoch,
                          mode: _mode.name,
                          reps: repsReal,
                          sec: secReal,
                          kcal: kcalReal,
                        ),
                      );

                      await WeeklyGoalStore.markTodayDone();

                      await WorkoutStatsStore.addSession(
                        seconds: secReal,
                        sessionKcal: kcalReal,
                      );

                      if (mounted) {
                        Navigator.popUntil(
                          context,
                          ModalRoute.withName('/'),
                        );
                      }
                    },
                    child: Text(
                      _isTutorial ? '終了（チュートリアルを抜ける）' : '終了（メニュー全体）',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidCameraWithOverlay() {
    if (!(_camController?.value.isInitialized ?? false)) {
      return const ColoredBox(color: Colors.black);
    }

    final controller = _camController!;
    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }

    final DeviceOrientation? devOrientation = controller.value.deviceOrientation;

    final bool isPortrait = devOrientation == null ||
        devOrientation == DeviceOrientation.portraitUp ||
        devOrientation == DeviceOrientation.portraitDown;

    final bool isLandscapeLeft =
        devOrientation == DeviceOrientation.landscapeLeft;
    final bool isLandscapeRight =
        devOrientation == DeviceOrientation.landscapeRight;

    final double previewW = isPortrait ? previewSize.height : previewSize.width;
    final double previewH = isPortrait ? previewSize.width : previewSize.height;

    final bool mirrorSkeleton = _currentFacing == AppCameraFacing.front;

    final List<Offset> drawLandmarks;
    if (isPortrait) {
      drawLandmarks = _landmarks;
    } else if (isLandscapeLeft) {
      drawLandmarks = _rotateLmForLandscape(_landmarks, clockwise: false);
    } else if (isLandscapeRight) {
      drawLandmarks = _rotateLmForLandscape(_landmarks, clockwise: true);
    } else {
      drawLandmarks = _landmarks;
    }

    final stackedPreview = SizedBox(
      width: previewW,
      height: previewH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          cam.CameraPreview(controller),
          IgnorePointer(
            child: CustomPaint(
              painter: _SkeletonPainter(
                drawLandmarks,
                mirrorX: mirrorSkeleton,
                style: _skeletonStyle,
              ),
            ),
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: stackedPreview,
    );
  }

  List<Offset> _rotateLmForLandscape(
    List<Offset> src, {
    required bool clockwise,
  }) {
    if (src.isEmpty) return src;
    return src.map((p) {
      if (p.dx.isNaN || p.dy.isNaN) return p;
      final double x = p.dx;
      final double y = p.dy;

      if (clockwise) {
        final double nx = y;
        final double ny = 1.0 - x;
        return Offset(nx, ny);
      } else {
        final double nx = 1.0 - y;
        final double ny = x;
        return Offset(nx, ny);
      }
    }).toList(growable: false);
  }

  double _pickMetricDouble(List<String> keys, {double fallback = 0.0}) {
    for (final k in keys) {
      final v = _state.metrics[k];
      final d = _asDouble(v);
      if (d != null) return d;
    }
    return fallback;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v);
      if (p != null) return p;
    }
    final s = v.toString();
    return double.tryParse(s);
  }

  Uint8List _concatPlanes(List<cam.Plane> planes) {
    final builder = BytesBuilder(copy: false);
    for (final p in planes) {
      builder.add(p.bytes);
    }
    return builder.toBytes();
  }

  ml.InputImageRotation _rotationFromController(cam.CameraController c) {
    switch (c.description.sensorOrientation) {
      case 0:
        return ml.InputImageRotation.rotation0deg;
      case 90:
        return ml.InputImageRotation.rotation90deg;
      case 180:
        return ml.InputImageRotation.rotation180deg;
      case 270:
        return ml.InputImageRotation.rotation270deg;
      default:
        return ml.InputImageRotation.rotation0deg;
    }
  }

  Offset get _invalid => const Offset(double.nan, double.nan);
  List<Offset> _convertWebNamedToBlazeList(dynamic named) {
    final list = List<Offset>.filled(33, _invalid, growable: false);

    Offset? _toOffset(dynamic v) {
      if (v is Map && v['x'] != null && v['y'] != null) {
        final x = (v['x'] as num).toDouble();
        final y = (v['y'] as num).toDouble();
        return Offset(x, y);
      }
      return null;
    }

    final m = (named is Map) ? named : const {};
    final mapIndex = <int, String>{
      11: 'leftShoulder',
      12: 'rightShoulder',
      13: 'leftElbow',
      14: 'rightElbow',
      15: 'leftWrist',
      16: 'rightWrist',
      23: 'leftHip',
      24: 'rightHip',
      25: 'leftKnee',
      26: 'rightKnee',
      27: 'leftAnkle',
      28: 'rightAnkle',
    };

    mapIndex.forEach((idx, key) {
      final v = _toOffset(m[key]);
      if (v != null) list[idx] = v;
    });

    return list;
  }

  Widget _chip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(value),
          ],
        ),
      ),
    );
  }

  Widget _cueBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2962FF).withOpacity(0.90),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================ 骨格描画（デザイン切替） ======================
enum SkeletonStyle {
  thin,
  neon,
  dashed,
  joints,
  minimal,
}

class _SkeletonPainter extends CustomPainter {
  final List<Offset> lms01;
  final bool mirrorX;
  final SkeletonStyle style;

  _SkeletonPainter(
    this.lms01, {
    this.mirrorX = false,
    this.style = SkeletonStyle.neon,
  });

  static const _pairsFull = [
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [11, 23],
    [12, 24],
    [23, 24],
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
  ];

  static const _pairsMinimal = [
    [11, 12],
    [11, 23],
    [12, 24],
    [23, 24],
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
  ];

  bool _valid(int i) =>
      i >= 0 &&
      i < lms01.length &&
      !(lms01[i].dx.isNaN || lms01[i].dy.isNaN);

  Offset _tr(Size size, int i) =>
      Offset(lms01[i].dx * size.width, lms01[i].dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (lms01.isEmpty) return;

    if (mirrorX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final pairs = (style == SkeletonStyle.minimal) ? _pairsMinimal : _pairsFull;

    final double baseStroke = switch (style) {
      SkeletonStyle.thin => 2.0,
      SkeletonStyle.neon => 3.0,
      SkeletonStyle.dashed => 3.0,
      SkeletonStyle.joints => 2.5,
      SkeletonStyle.minimal => 3.0,
    };

    final Color lineColor = switch (style) {
      SkeletonStyle.thin => Colors.white70,
      SkeletonStyle.neon => const Color(0xFF4DD0FF),
      SkeletonStyle.dashed => const Color(0xFF4DD0FF),
      SkeletonStyle.joints => Colors.white60,
      SkeletonStyle.minimal => Colors.white70,
    };

    final line = Paint()
      ..strokeWidth = baseStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = lineColor;

    final outerLine = Paint()
      ..strokeWidth = baseStroke + 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.85);

    Paint? glow;
    if (style == SkeletonStyle.neon) {
      glow = Paint()
        ..strokeWidth = baseStroke * 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = lineColor.withOpacity(0.18);
    }

    final double jointR = switch (style) {
      SkeletonStyle.thin => 2.5,
      SkeletonStyle.neon => 3.2,
      SkeletonStyle.dashed => 3.0,
      SkeletonStyle.joints => 5.0,
      SkeletonStyle.minimal => 3.0,
    };

    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = (style == SkeletonStyle.neon)
          ? Colors.white.withOpacity(0.95)
          : Colors.white.withOpacity(0.85);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = (style == SkeletonStyle.joints)
          ? const Color(0xFF4DD0FF).withOpacity(0.9)
          : Colors.transparent;

    for (final p in pairs) {
      final a = p[0], b = p[1];
      if (!_valid(a) || !_valid(b)) continue;

      final pa = _tr(size, a);
      final pb = _tr(size, b);

      if (style == SkeletonStyle.dashed) {
        _drawDashedLine(canvas, pa, pb, line, dash: 10, gap: 8);
      } else {
        if (glow != null) canvas.drawLine(pa, pb, glow);

        if (style == SkeletonStyle.neon) {
          canvas.drawLine(pa, pb, outerLine);
          canvas.drawLine(pa, pb, line);
        } else {
          canvas.drawLine(pa, pb, line);
        }
      }
    }

    final Set<int> jointsToShow = switch (style) {
      SkeletonStyle.minimal => {11, 12, 23, 24, 25, 26, 27, 28},
      _ => {11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28},
    };

    for (final i in jointsToShow) {
      if (!_valid(i)) continue;
      final c = _tr(size, i);

      if (style == SkeletonStyle.neon) {
        final glowDot = Paint()..color = lineColor.withOpacity(0.22);
        canvas.drawCircle(c, jointR * 1.9, glowDot);
      }
      canvas.drawCircle(c, jointR, dot);

      if (style == SkeletonStyle.joints) {
        canvas.drawCircle(c, jointR + 2.2, ring);
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dash = 10,
    double gap = 8,
  }) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= 0.001) return;

    final ux = dx / dist;
    final uy = dy / dist;

    double t = 0;
    while (t < dist) {
      final t2 = (t + dash).clamp(0.0, dist);
      final p1 = Offset(a.dx + ux * t, a.dy + uy * t);
      final p2 = Offset(a.dx + ux * t2, a.dy + uy * t2);
      canvas.drawLine(p1, p2, paint);
      t = t2 + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) =>
      old.mirrorX != mirrorX ||
      old.style != style ||
      !const ListEquality<Offset>().equals(old.lms01, lms01);
}

// ============================ 簡易休憩画面 ==================================
class _RestScreen extends StatefulWidget {
  const _RestScreen();
  @override
  State<_RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<_RestScreen> {
  int sec = 30;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => sec = (sec - 1).clamp(0, 9999));
      if (sec == 0) {
        _t?.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('休憩')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$sec',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text('秒 休憩', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('スキップ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ 内部: 実効FPSメーター ==========================
class _FpsMeter {
  final int _windowMs = 1000;
  final List<int> _ts = <int>[];

  void tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _ts.add(now);
    while (_ts.isNotEmpty && now - _ts.first > _windowMs) {
      _ts.removeAt(0);
    }
  }

  double get value {
    if (_ts.length < 2) return 0.0;
    final dt = (_ts.last - _ts.first).clamp(1, 1 << 31);
    return (_ts.length - 1) * 1000.0 / dt;
  }

  String get label => '${value.toStringAsFixed(1)} FPS';
}

class _OneEuro2D {
  final _OneEuroFilter _fx;
  final _OneEuroFilter _fy;

  _OneEuro2D({
    required double minCutoff,
    required double beta,
    required double dCutoff,
  })  : _fx = _OneEuroFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        ),
        _fy = _OneEuroFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        );

  Offset filter(Offset v, double dt) {
    return Offset(
      _fx.filter(v.dx, dt),
      _fy.filter(v.dy, dt),
    );
  }
}

class _OneEuroFilter {
  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _xHat;
  double? _dxHat;

  _OneEuroFilter({
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
  });

  double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double filter(double x, double dt) {
    if (_xHat == null) {
      _xHat = x;
      _dxHat = 0.0;
      return x;
    }

    final prevX = _xHat!;
    final dx = (x - prevX) / dt;

    final aD = _alpha(dCutoff, dt);
    _dxHat = _dxHat! + (dx - _dxHat!) * aD;

    final cutoff = minCutoff + beta * _dxHat!.abs();

    final aX = _alpha(cutoff, dt);
    _xHat = prevX + (x - prevX) * aX;
    return _xHat!;
  }
}
