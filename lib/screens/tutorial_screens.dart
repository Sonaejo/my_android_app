// lib/screens/tutorial_screens.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vmath;
import 'package:collection/collection.dart';

// Web: poseStart / poseStop / CustomEvent('pose', {detail:{landmarks:...}})
// ★注意: エラーイベントは "error" を使わず "pose_error" を使う（標準ErrorEventと衝突するため）
import '../web_stubs/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import '../web_stubs/jsutil_stub.dart'
    if (dart.library.html) 'dart:js_util' as jsutil;

// Android: Camera + ML Kit Pose
import 'package:camera/camera.dart' as cam;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml;

const _accentBlue = Color(0xFF2962FF);

/// =============== 1. ようこそ画面 ==========================================
class TutorialWelcomeScreen extends StatefulWidget {
  const TutorialWelcomeScreen({super.key});

  @override
  State<TutorialWelcomeScreen> createState() => _TutorialWelcomeScreenState();
}

class _TutorialWelcomeScreenState extends State<TutorialWelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // ★ Android のときだけ縦画面に固定
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    // ★ 戻るときに元の設定（全方向許可）に戻す
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'チュートリアル',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      // ✅ スクロールは入れない（禁止）
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'AIフォームチェックへようこそ！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'このチュートリアルでは、次のことを体験できます：\n\n'
                '・カメラの位置と距離の確認\n'
                '・骨格ラインの見え方\n'
                '・スクワットのカウント方法',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const _StepBullets(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/tutorial_camera');
                  },
                  child: const Text(
                    'チュートリアルを開始する',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBullets extends StatelessWidget {
  const _StepBullets();

  @override
  Widget build(BuildContext context) {
    final items = [
      'ステップ1  全身を映してみよう！',
      'ステップ2  手を上げてみよう！',
      'ステップ3  スクワットを 3回してみよう！',
      'チュートリアル完了',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'チュートリアルの流れ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(items.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _accentBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// AppBar の戻るボタン：常にホームへ戻る
class _HomeBackButton extends StatelessWidget {
  const _HomeBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        Navigator.popUntil(context, (route) => route.isFirst);
      },
    );
  }
}

/// AppBar のスキップボタン：ステップ1〜3共通（次の画面へ）
class _SkipButton extends StatelessWidget {
  const _SkipButton({super.key, required this.nextRoute});

  final String nextRoute;

  @override
  Widget build(BuildContext context) {
    final color = kIsWeb ? Colors.white : _accentBlue;
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, nextRoute);
      },
      child: Text(
        'スキップ',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// =============== 2. カメラ位置チュートリアル ==============================
class TutorialCameraPositionScreen extends StatefulWidget {
  const TutorialCameraPositionScreen({super.key});

  @override
  State<TutorialCameraPositionScreen> createState() =>
      _TutorialCameraPositionScreenState();
}

class _TutorialCameraPositionScreenState
    extends State<TutorialCameraPositionScreen> {
  bool _isOkDistance = false;
  Timer? _okTimer;
  bool _navigating = false; // ✅ 二重遷移ガード
  String _message = 'カメラを少し離して、全身が入るようにしてください。';

  @override
  void initState() {
    super.initState();
    // ★ Android のときだけ縦画面に固定
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    _okTimer?.cancel();
    // ★ 戻るときに元の設定（全方向許可）に戻す
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  void _goNext() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.pushNamed(context, '/tutorial_skeleton');
  }

  void _setOkDistance(bool ok) {
    if (_isOkDistance == ok) return;
    setState(() {
      _isOkDistance = ok;
      _message = ok
          ? 'その位置でOKです！そのまま少しキープしてください。'
          : 'カメラを少し離して、全身が入るようにしてください。';
    });

    _okTimer?.cancel();
    if (ok) {
      _okTimer = Timer(const Duration(seconds: 2), _goNext);
    }
  }

  /// ポーズ検出から毎フレーム渡されるランドマーク（0..1正規化）
  void _onPoseForDistance(List<Offset> lms) {
    if (lms.isEmpty) {
      _setOkDistance(false);
      return;
    }
    // 肩〜足首の高さを使って「全身の占有率」を見る
    final idx = [11, 12, 23, 24, 25, 26, 27, 28];
    double? minY;
    double? maxY;
    for (final i in idx) {
      if (i >= lms.length) continue;
      final p = lms[i];
      if (p.dx.isNaN || p.dy.isNaN) continue;
      minY = (minY == null) ? p.dy : math.min(minY!, p.dy);
      maxY = (maxY == null) ? p.dy : math.max(maxY!, p.dy);
    }
    if (minY == null || maxY == null) {
      _setOkDistance(false);
      return;
    }
    final bodyH = (maxY! - minY!).clamp(0.0, 1.0);

    // 小さすぎ → 遠すぎ, 大きすぎ → 近すぎ, 中間をOK扱い
    final bool ok = bodyH >= 0.45 && bodyH <= 0.75;
    _setOkDistance(ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? Colors.transparent : Colors.white,
      appBar: AppBar(
        leading: const _HomeBackButton(),
        actions: const [_SkipButton(nextRoute: '/tutorial_skeleton')],
        title: kIsWeb
            ? const StrokeText(
                text: '全身を映してみよう！',
                fontSize: 20,
                strokeWidth: 2,
                strokeColor: Colors.black,
                textColor: Colors.white,
                align: TextAlign.center,
              )
            : const Text(
                '全身を映してみよう！',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              ),
        backgroundColor: kIsWeb ? Colors.transparent : Colors.white,
        foregroundColor: kIsWeb ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: kIsWeb
                // ✅ Webは縁取り（他と統一）
                ? StrokeText(
                    text: _message,
                    fontSize: 18,
                    strokeWidth: 2.2,
                    strokeColor: Colors.black,
                    textColor: Colors.white,
                    align: TextAlign.center,
                  )
                // Androidは通常Text（白地で読みやすい）
                : Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: kIsWeb
                  // ---------- Web: 画面全体にカメラ＋骨格 ----------
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: _TutorialPoseCameraInner(
                            onPose: _onPoseForDistance,
                            showSkeleton: true,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StrokeText(
                              text: _isOkDistance ? 'OK 距離' : '距離調整中…',
                              fontSize: 18,
                              strokeWidth: 2,
                              strokeColor: Colors.black,
                              textColor: _isOkDistance
                                  ? Colors.lightGreenAccent
                                  : Colors.white70,
                              align: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  // ---------- Android: 黒カード全体にカメラを表示 ----------
                  : AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF111111)),
                            _TutorialPoseCameraInner(
                              onPose: _onPoseForDistance,
                              showSkeleton: true,
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _isOkDistance ? 'OK 距離' : '距離調整中…',
                                  style: TextStyle(
                                    color: _isOkDistance
                                        ? Colors.lightGreenAccent
                                        : Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// =============== 3. 骨格ラインの表示を理解 ================================
class TutorialSkeletonPreviewScreen extends StatefulWidget {
  const TutorialSkeletonPreviewScreen({super.key});

  @override
  State<TutorialSkeletonPreviewScreen> createState() =>
      _TutorialSkeletonPreviewScreenState();
}

class _TutorialSkeletonPreviewScreenState
    extends State<TutorialSkeletonPreviewScreen> {
  bool _armUp = false;
  bool _completed = false;
  bool _navigating = false; // 二重遷移ガード
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();
    // ★ Android のときだけ縦画面に固定
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    // ★ 戻るときに元の設定（全方向許可）に戻す
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  void _goNext() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.pushNamed(context, '/tutorial_squat');
  }

  void _setArmUp(bool up) {
    if (_completed) return;
    setState(() => _armUp = up);

    if (up) {
      _completed = true;
      _completeTimer?.cancel();
      _completeTimer = Timer(const Duration(seconds: 2), _goNext);
    }
  }

  /// 腕が十分上がったら true にする
  void _onPoseForArm(List<Offset> lms) {
    if (lms.length < 29) return;

    // 体の高さ（肩〜足首）でしきい値をスケーリング
    double? minY;
    double? maxY;
    for (final i in [11, 12, 27, 28]) {
      if (i >= lms.length) continue;
      final p = lms[i];
      if (p.dx.isNaN || p.dy.isNaN) continue;
      minY = (minY == null) ? p.dy : math.min(minY!, p.dy);
      maxY = (maxY == null) ? p.dy : math.max(maxY!, p.dy);
    }
    if (minY == null || maxY == null) return;

    final bodyH = (maxY! - minY!).clamp(0.2, 1.0);

    bool sideUp(int sIdx, int wIdx) {
      if (sIdx >= lms.length || wIdx >= lms.length) return false;
      final s = lms[sIdx];
      final w = lms[wIdx];
      if (s.dx.isNaN || s.dy.isNaN || w.dx.isNaN || w.dy.isNaN) return false;
      // 「手首が肩より bodyH*0.15 以上上」にあるか
      return w.dy < s.dy - bodyH * 0.15;
    }

    final up = sideUp(11, 15) || sideUp(12, 16);
    if (up) _setArmUp(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? Colors.transparent : Colors.white,
      appBar: AppBar(
        leading: const _HomeBackButton(),
        actions: const [_SkipButton(nextRoute: '/tutorial_squat')],
        title: kIsWeb
            ? const StrokeText(
                text: '腕をあげてみよう！',
                fontSize: 20,
                strokeWidth: 2,
                strokeColor: Colors.black,
                textColor: Colors.white,
                align: TextAlign.center,
              )
            : const Text(
                '腕をあげてみよう！',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              ),
        backgroundColor: kIsWeb ? Colors.transparent : Colors.white,
        foregroundColor: kIsWeb ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: kIsWeb
                ? const StrokeText(
                    text:
                        '腕をゆっくり上げてみてください。\n腕が十分上がると、枠の色が変わります。',
                    fontSize: 18,
                    strokeWidth: 2.2,
                    strokeColor: Colors.black,
                    textColor: Colors.white,
                    align: TextAlign.left,
                  )
                : const Text(
                    '腕をゆっくり上げてみてください。\n腕が十分上がると、枠の色が変わります。',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: kIsWeb
                  // ---------- Web: 背景フル画面 ----------
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: _TutorialPoseCameraInner(
                            onPose: _onPoseForArm,
                            showSkeleton: true,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StrokeText(
                              text: _armUp
                                  ? '腕を上げました！'
                                  : '腕をゆっくり上げてみましょう',
                              fontSize: 18,
                              strokeWidth: 2,
                              strokeColor: Colors.black,
                              textColor: _armUp
                                  ? Colors.lightGreenAccent
                                  : Colors.white70,
                              align: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  // ---------- Android: 黒カード全体にカメラを表示 ----------
                  : AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF111111)),
                            _TutorialPoseCameraInner(
                              onPose: _onPoseForArm,
                              showSkeleton: true,
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _armUp
                                      ? '腕を上げました！'
                                      : '腕をゆっくり上げてみましょう',
                                  style: TextStyle(
                                    color: _armUp
                                        ? Colors.lightGreenAccent
                                        : Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// =============== 4. ミニスクワット体験 ====================================
class TutorialMiniSquatScreen extends StatefulWidget {
  const TutorialMiniSquatScreen({super.key});

  @override
  State<TutorialMiniSquatScreen> createState() =>
      _TutorialMiniSquatScreenState();
}

class _TutorialMiniSquatScreenState extends State<TutorialMiniSquatScreen> {
  int _count = 0;
  bool _completed = false;
  bool _navigating = false; // 二重遷移ガード

  static const int _targetCount = 3;

  // 簡易スクワットFSM
  // 0: 立ち, 1: しゃがみ
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    // ★ Android のときだけ縦画面に固定
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    // ★ 戻るときに元の設定（全方向許可）に戻す
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  void _goNext() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.pushNamed(context, '/tutorial_done');
  }

  void _onRep() {
    if (_completed) return;
    setState(() => _count++);
    if (_count >= _targetCount) {
      _completed = true;
      Future.delayed(const Duration(seconds: 2), _goNext);
    }
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

  /// ポーズからスクワット回数を推定
  void _onPoseForSquat(List<Offset> lms) {
    if (lms.length < 29) return;

    Offset? getP(int i) {
      if (i < 0 || i >= lms.length) return null;
      final p = lms[i];
      if (p.dx.isNaN || p.dy.isNaN) return null;
      return p;
    }

    final lh = getP(23);
    final rh = getP(24);
    final lk = getP(25);
    final rk = getP(26);
    final la = getP(27);
    final ra = getP(28);
    if ([lh, rh, lk, rk, la, ra].any((p) => p == null)) return;

    final leftKnee = _kneeAngleDeg(lh!, lk!, la!);
    final rightKnee = _kneeAngleDeg(rh!, rk!, ra!);

    final knee = math.min(leftKnee, rightKnee);

    // ざっくり基準：
    //  170° 以上 → 立ち
    //  145° 以下 → しゃがみ
    const standTh = 170.0;
    const squatTh = 145.0;

    if (_phase == 0) {
      if (knee < squatTh) {
        _phase = 1;
      }
    } else if (_phase == 1) {
      if (knee > standTh) {
        _phase = 0;
        _onRep();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? Colors.transparent : Colors.white,
      appBar: AppBar(
        leading: const _HomeBackButton(),
        actions: const [_SkipButton(nextRoute: '/tutorial_done')],
        title: kIsWeb
            ? const StrokeText(
                text: 'スクワットを3回やってみよう',
                fontSize: 20,
                strokeWidth: 2,
                strokeColor: Colors.black,
                textColor: Colors.white,
                align: TextAlign.center,
              )
            : const Text(
                'スクワットを3回やってみよう',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              ),
        backgroundColor: kIsWeb ? Colors.transparent : Colors.white,
        foregroundColor: kIsWeb ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: kIsWeb
                ? StrokeText(
                    text: 'スクワットを $_targetCount 回だけやってみましょう。\n',
                    fontSize: 18,
                    strokeWidth: 2.2,
                    strokeColor: Colors.black,
                    textColor: Colors.white,
                    align: TextAlign.left,
                  )
                : Text(
                    'スクワットを $_targetCount 回だけやってみましょう。\n',
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: kIsWeb
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: _TutorialPoseCameraInner(
                            onPose: _onPoseForSquat,
                            showSkeleton: true,
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _SquatHud(
                            count: _count,
                            target: _targetCount,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StrokeText(
                              text: _completed
                                  ? 'お疲れさまでした！'
                                  : 'しゃがんで・立ち上がる動きをしてみましょう',
                              fontSize: 18,
                              strokeWidth: 2,
                              strokeColor: Colors.black,
                              textColor: _completed
                                  ? Colors.lightGreenAccent
                                  : Colors.white70,
                              align: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF111111)),
                            _TutorialPoseCameraInner(
                              onPose: _onPoseForSquat,
                              showSkeleton: true,
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: _SquatHud(
                                count: _count,
                                target: _targetCount,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _completed
                                      ? 'お疲れさまでした！'
                                      : 'しゃがんで・立ち上がる動きをしてみましょう',
                                  style: TextStyle(
                                    color: _completed
                                        ? Colors.lightGreenAccent
                                        : Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SquatHud extends StatelessWidget {
  const _SquatHud({required this.count, required this.target});

  final int count;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = (count / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'スクワット',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count / $target 回',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 120,
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.lightGreenAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============== 5. チュートリアル完了画面 =================================
class TutorialFinishScreen extends StatefulWidget {
  const TutorialFinishScreen({super.key});

  @override
  State<TutorialFinishScreen> createState() => _TutorialFinishScreenState();
}

class _TutorialFinishScreenState extends State<TutorialFinishScreen> {
  @override
  void initState() {
    super.initState();
    // ★ 中3つと同じ：Android のときだけ縦画面に固定
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    // ★ 中3つと同じ：戻るときに元の設定（全方向許可）に戻す
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const _HomeBackButton(),
        title: const Text(
          'チュートリアル完了',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      // ✅ スクロールは入れない（禁止）
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.emoji_events,
                size: 72,
                color: _accentBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                'チュートリアル完了！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'カメラの位置・骨格表示・スクワットの\n'
                'カウント方法を体験できました。\n\n'
                '次は本番トレーニングで、\n'
                '自分のペースでチャレンジしてみましょう！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/counter',
                      arguments: {'mode': 'squat'},
                    );
                  },
                  child: const Text(
                    'スクワットを始める',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text(
                  'ホーム画面に戻る',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==========================================================================
/// 共有：チュートリアル用のシンプルなカメラ＋ポーズ検出ウィジェット
/// ==========================================================================

typedef PoseLandmarksCallback = void Function(List<Offset> lms01);

class _TutorialPoseCameraInner extends StatefulWidget {
  const _TutorialPoseCameraInner({
    required this.onPose,
    this.showSkeleton = true,
  });

  final PoseLandmarksCallback onPose;
  final bool showSkeleton;

  @override
  State<_TutorialPoseCameraInner> createState() =>
      _TutorialPoseCameraInnerState();
}

class _TutorialPoseCameraInnerState extends State<_TutorialPoseCameraInner> {
  // 共通：正規化ランドマーク
  List<Offset> _landmarks = const [];

  // Web
  html.EventListener? _poseListener;
  html.EventListener? _errorListener;

  // Android
  cam.CameraController? _controller;
  ml.PoseDetector? _detector;
  bool _processing = false;

  // ✅ 平滑化（One Euro Filter + ジャンプ抑制 + 短ホールド）
  List<Offset>? _smooth; // 状態保持（33点）
  final List<OneEuro2D?> _filters = List<OneEuro2D?>.filled(33, null);

  int? _lastUs; // dt計測用（microseconds）
  static const double _jumpTh = 0.15; // 急ジャンプ抑制（0..1正規化）

  Timer? _holdTimer; // 検出途切れ時の短時間ホールド
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWeb();
    } else {
      _initAndroid();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    if (kIsWeb) {
      if (_poseListener != null) {
        html.window.removeEventListener('pose', _poseListener!);
      }
      // ★ "pose_error" に変更
      if (_errorListener != null) {
        html.window.removeEventListener('pose_error', _errorListener!);
      }
      try {
        jsutil.callMethod(html.window, 'poseStop', const []);
      } catch (_) {}
    } else {
      _controller?.dispose();
      _detector?.close();
    }
    super.dispose();
  }

  bool _valid(Offset p) => !(p.dx.isNaN || p.dy.isNaN);

  double _calcDtSec() {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    final last = _lastUs;
    _lastUs = nowUs;
    if (last == null) return 1.0 / 30.0;

    final dt = (nowUs - last) / 1e6;
    // dtが異常値だとフィルタが暴れるので安全に丸める
    return dt.clamp(1.0 / 120.0, 1.0 / 10.0);
  }

  void _resetFilters() {
    for (int i = 0; i < _filters.length; i++) {
      _filters[i] = null;
    }
    _smooth = null;
    _lastUs = null;
  }

  List<Offset> _smoothLandmarks(List<Offset> cur) {
    // 検出なし → いきなり消すとチラつくので、短時間だけ前を保持
    if (cur.isEmpty) {
      if (!_holding && (_smooth != null)) {
        _holding = true;
        _holdTimer?.cancel();
        _holdTimer = Timer(const Duration(milliseconds: 150), () {
          _holding = false;
          _resetFilters();
          if (!mounted) return;
          setState(() => _landmarks = const []);
          widget.onPose(const []);
        });
      }
      return _smooth ?? const [];
    }

    // ちゃんと来たらホールド解除
    _holdTimer?.cancel();
    _holding = false;

    final dt = _calcDtSec();

    // 初回
    _smooth ??= List<Offset>.from(cur);
    final prev = _smooth!;
    final out = List<Offset>.from(prev);

    for (int i = 0; i < cur.length && i < 33; i++) {
      final c = cur[i];
      if (!_valid(c)) continue;

      final p = prev[i];

      // フィルタ作成（止まると強く平滑／動くと追従）
      _filters[i] ??= OneEuro2D(
        minCutoff: 2.2,
        beta: 0.08,
        dCutoff: 1.0,
      );

      // 急ジャンプ（誤検出）だけは OneEuro に入れる前に吸収
      if (_valid(p)) {
        final dx = c.dx - p.dx;
        final dy = c.dy - p.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > _jumpTh) {
          final softened = Offset(
            p.dx + dx * 0.35,
            p.dy + dy * 0.35,
          );
          out[i] = _filters[i]!.filter(softened, dt);
          continue;
        }
      }

      // 通常：OneEuroで平滑化
      out[i] = _filters[i]!.filter(c, dt);
    }

    _smooth = out;
    return out;
  }

  void _updatePose(List<Offset> lms) {
    if (!mounted) return;

    final smoothed = _smoothLandmarks(lms);

    setState(() {
      _landmarks = smoothed;
    });

    widget.onPose(smoothed);
  }

  // ---------------- Web ----------------------------------------------------
  void _initWeb() {
    // ✅ pose は CustomEvent 前提だが、念のため型チェックする
    _poseListener = (ev) {
      if (ev is! html.CustomEvent) return;
      final detail = ev.detail;
      if (detail is Map && detail['landmarks'] != null) {
        final lms = _convertWebNamedToBlazeList(detail['landmarks']);
        _updatePose(lms);
      }
    };
    html.window.addEventListener('pose', _poseListener!);

    // ★重要：標準 "error" イベントは ErrorEvent で来るので使わない。
    // JS側は CustomEvent('pose_error', {detail:{message}}) を投げること。
    _errorListener = (ev) {
      if (ev is! html.CustomEvent) return;
      final detail = ev.detail;

      final msg = (detail is Map)
          ? (detail['message'] ?? 'unknown error').toString()
          : 'unknown error';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Webカメラ/姿勢 読み込みエラー: $msg')),
      );
    };
    html.window.addEventListener('pose_error', _errorListener!);

    try {
      jsutil.callMethod(html.window, 'poseStart', const []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('poseStart 呼び出しに失敗: $e')),
      );
    }
  }

  // ---------------- Android ------------------------------------------------
  Future<void> _initAndroid() async {
    try {
      final cameras = await cam.availableCameras();
      // フロント優先
      cam.CameraDescription pickFront() => cameras.firstWhere(
            (c) => c.lensDirection == cam.CameraLensDirection.front,
            orElse: () => cameras.first,
          );
      final selected = pickFront();

      _controller = cam.CameraController(
        selected,
        cam.ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: cam.ImageFormatGroup.nv21,
      );
      await _controller!.initialize();

      final options = ml.PoseDetectorOptions(
        mode: ml.PoseDetectionMode.stream,
        model: ml.PoseDetectionModel.base,
      );
      _detector = ml.PoseDetector(options: options);

      _controller!.startImageStream((cam.CameraImage image) async {
        if (_processing) return;
        _processing = true;
        try {
          final cam.Plane plane = image.planes.first;
          final Uint8List bytes = plane.bytes;

          final rotation = _rotationFromController(_controller!);

          double imageW = image.width.toDouble();
          double imageH = image.height.toDouble();
          if (rotation == ml.InputImageRotation.rotation90deg ||
              rotation == ml.InputImageRotation.rotation270deg) {
            final tmp = imageW;
            imageW = imageH;
            imageH = tmp;
          }

          final inputImage = ml.InputImage.fromBytes(
            bytes: bytes,
            metadata: ml.InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: rotation,
              format: ml.InputImageFormat.nv21,
              bytesPerRow: plane.bytesPerRow,
            ),
          );

          final poses = await _detector!.processImage(inputImage);
          if (poses.isNotEmpty) {
            final pose = poses.first;
            final lms = _convertMlPoseToBlazeList(pose, imageW, imageH);
            _updatePose(lms);
          } else {
            _updatePose(const []);
          }
        } catch (_) {
          // ignore errors in demo
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

  // ---------------- build --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web: 背面の <video> を利用。ここでは骨格ラインだけ描画。
      return ColoredBox(
        color: Colors.transparent,
        child: CustomPaint(
          painter: widget.showSkeleton
              ? _SkeletonPainter(
                  _landmarks,
                  mirrorX: true,
                  style: SkeletonStyle.neon,
                  yShift01: -0.1, // ✅ Webチュートリアルだけ上へ
                )
              : const _SkeletonPainter.empty(),
        ),
      );

    }

    // Android
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }

    final previewW = previewSize.height;
    final previewH = previewSize.width;

    final stacked = SizedBox(
      width: previewW,
      height: previewH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          cam.CameraPreview(controller),
          if (widget.showSkeleton)
            IgnorePointer(
              child: CustomPaint(
                painter: _SkeletonPainter(
                  _landmarks,
                  mirrorX: true,
                  style: SkeletonStyle.neon,
                ),
              ),
            ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: stacked,
    );
  }

  // ---------------- helpers ------------------------------------------------
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

  // ML Kit Pose → BlazePose 33点の一部を 0..1 正規化で埋める
  List<Offset> _convertMlPoseToBlazeList(
      ml.Pose pose, double imageW, double imageH) {
    final list = List<Offset>.filled(
      33,
      const Offset(double.nan, double.nan),
      growable: false,
    );

    final byType = pose.landmarks;
    Offset? getL(ml.PoseLandmarkType t) {
      final kp = byType[t];
      if (kp == null) return null;
      return Offset(kp.x / imageW, kp.y / imageH);
    }

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

    return list;
  }

  // Web named(12点) → BlazePose(33点)
  List<Offset> _convertWebNamedToBlazeList(dynamic named) {
    const invalid = Offset(double.nan, double.nan);
    final list = List<Offset>.filled(33, invalid, growable: false);

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
}

/// 2D One Euro Filter（x/y別に適用）
class OneEuro2D {
  final OneEuroFilter _fx;
  final OneEuroFilter _fy;

  OneEuro2D({
    required double minCutoff,
    required double beta,
    required double dCutoff,
  })  : _fx = OneEuroFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        ),
        _fy = OneEuroFilter(
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

/// One Euro Filter（数値1次元）
class OneEuroFilter {
  final double minCutoff; // Hz
  final double beta; // speed coefficient
  final double dCutoff; // Hz

  double? _xHat;
  double? _dxHat;

  OneEuroFilter({
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
  });

  double _alpha(double cutoff, double dt) {
    // alpha = 1 / (1 + tau/dt), tau = 1/(2*pi*cutoff)
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

    // 速度をまず平滑化
    final aD = _alpha(dCutoff, dt);
    _dxHat = _dxHat! + (dx - _dxHat!) * aD;

    // 動きが大きいほど cutoff を上げて追従性UP（遅延DOWN）
    final cutoff = minCutoff + beta * _dxHat!.abs();

    final aX = _alpha(cutoff, dt);
    _xHat = prevX + (x - prevX) * aX;
    return _xHat!;
  }
}

// ======================== 骨格描画（デザイン切替） ======================
enum SkeletonStyle {
  thin, // 細い白線（主張弱め）
  neon, // ネオン＋うっすらグロー
  dashed, // 点線
  joints, // 関節を強調（線は控えめ）
  minimal, // 主要部位だけ（見やすい）
}

class _SkeletonPainter extends CustomPainter {
  final List<Offset> lms01; // 0..1 正規化
  final bool mirrorX;
  final SkeletonStyle style;

  // ✅ 追加：Y方向の微調整（-なら上へ）
  final double yShift01;

  const _SkeletonPainter(
    this.lms01, {
    this.mirrorX = false,
    this.style = SkeletonStyle.neon,
    this.yShift01 = 0.0,
  });

  /// 空のプレースホルダ用
  const _SkeletonPainter.empty()
      : lms01 = const [],
        mirrorX = false,
        style = SkeletonStyle.neon,
        yShift01 = 0.0;

  bool _valid(int i) =>
      i >= 0 &&
      i < lms01.length &&
      !(lms01[i].dx.isNaN || lms01[i].dy.isNaN);

  // ✅ ここで yShift を反映（clampして画面外に行きすぎないように）
  Offset _tr(Size size, int i) {
    final x01 = lms01[i].dx;
    final y01 = (lms01[i].dy + yShift01).clamp(0.0, 1.0);
    return Offset(x01 * size.width, y01 * size.height);
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) =>
      old.mirrorX != mirrorX ||
      old.style != style ||
      old.yShift01 != yShift01 ||
      !const ListEquality<Offset>().equals(old.lms01, lms01);

  // BlazePose の主な接続（必要ならここを増減）
  static const _pairsFull = [
    [11, 12], // shoulders
    [11, 13],
    [13, 15], // left arm
    [12, 14],
    [14, 16], // right arm
    [11, 23],
    [12, 24], // torso
    [23, 24], // hips
    [23, 25],
    [25, 27], // left leg
    [24, 26],
    [26, 28], // right leg
  ];

  // 「見やすさ優先」：胴体＋脚中心
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

  @override
  void paint(Canvas canvas, Size size) {
    if (lms01.isEmpty) return;

    if (mirrorX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final pairs = (style == SkeletonStyle.minimal) ? _pairsMinimal : _pairsFull;

    // ---- スタイルごとの設定 ----
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

    // ★ 外側（白アウトライン）
    final outerLine = Paint()
      ..strokeWidth = baseStroke + 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.85);

    // ネオンの「うっすら発光」
    Paint? glow;
    if (style == SkeletonStyle.neon) {
      glow = Paint()
        ..strokeWidth = baseStroke * 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = lineColor.withOpacity(0.18);
    }

    // 点（関節）
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

    // joints 用：関節に外枠
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = (style == SkeletonStyle.joints)
          ? const Color(0xFF4DD0FF).withOpacity(0.9)
          : Colors.transparent;

    // ---- 線を描画 ----
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
          // ★白アウトライン → 青（内側）
          canvas.drawLine(pa, pb, outerLine);
          canvas.drawLine(pa, pb, line);
        } else {
          canvas.drawLine(pa, pb, line);
        }
      }
    }

    // ---- 点（関節）を描画 ----
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
}


/// 縁取りテキスト（2行以上でも自然に折り返す）
class StrokeText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color strokeColor;
  final Color textColor;
  final TextAlign align;

  const StrokeText({
    super.key,
    required this.text,
    this.fontSize = 16,
    this.strokeWidth = 2,
    this.strokeColor = Colors.black,
    this.textColor = Colors.white,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

extension _CustomPaintCopy on ColoredBox {
  /// CustomPaint を差し替えるための簡易ヘルパ（Web用）
  Widget copyWithPainter(CustomPainter? painter) {
    if (painter == null) return this;
    return ColoredBox(
      color: color,
      child: CustomPaint(
        painter: painter,
      ),
    );
  }
}
