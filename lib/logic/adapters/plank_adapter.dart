// lib/logic/adapters/plank_adapter.dart
import 'dart:ui' show Offset;
import '../pose_logic.dart';         // PoseLogic / PoseFrame / PoseState / PosePhase
import '../plank_logic.dart';        // あなたの PlankLogic（update() / reset() などを持つ）

/// PoseCounterScreen 用の共通IFに合わせた Plank アダプタ
/// - PoseFrame(lm01) → named landmarks(12点) に変換して PlankLogic.update() を呼ぶ
/// - Plank は保持系なので reps=0。progress は straightScore(0..1) を流す
class PlankAdapter implements PoseLogic {
  final PlankLogic _logic;

  PlankAdapter(PlankLogic? inner) : _logic = inner ?? PlankLogic();

  @override
  String get id => 'plank';

  @override
  void reset() => _logic.reset();

  @override
  PoseState process(PoseFrame frame) {
    // 0..1 正規化の33点 → 必要12点だけを namedMap に
    final named = _toNamed12(frame.lm01);

    // viewportWidth は 0..1 正規化前提なら 1.0 でOK（PlankLogic が比率で使う想定）。
    // もし PlankLogic がピクセル依存の閾値を使う場合は、呼び出し側から実画面幅を渡すように拡張してください。
    final st = _logic.update(named, viewportWidth: 1.0);

    // ここでは reps は使わない（保持時間が主体）。progress に直線度を反映
    return PoseState(
      reps: 0,
      progress: _clamp01(st.straightScore),
      phase: PosePhase.running,
      calibrated: true,
      warns: {
        'form': !st.goodForm,
      },
      cues: st.cues,
      metrics: {
        'elapsedSec': st.currentHoldSec,
        'bestSec': st.bestHoldSec,
        'totalSec': st.totalHoldSec,
        'straightScore': st.straightScore,
        'goodForm': st.goodForm ? 1 : 0,
      },
      extras: const {},
    );
  }

  // ===== Helpers =====

  // BlazePose 33点 → PlankLogic が期待する named(12点)
  // 必要なキー: leftShoulder, rightShoulder, leftElbow, rightElbow,
  //             leftWrist, rightWrist, leftHip, rightHip,
  //             leftKnee, rightKnee, leftAnkle, rightAnkle
  Map<String, Offset> _toNamed12(List<Offset> lm01) {
    Offset? getSafe(int i) {
      if (i < 0 || i >= lm01.length) return null;
      final p = lm01[i];
      if (p.dx.isNaN || p.dy.isNaN) return null;
      return p;
    }

    // BlazePose index 対応（あなたの既存コードと同じ割り当て）
    final map = <String, Offset>{};

    void put(String key, int idx) {
      final v = getSafe(idx);
      if (v != null) map[key] = v;
    }

    put('leftShoulder', 11);
    put('rightShoulder', 12);
    put('leftElbow', 13);
    put('rightElbow', 14);
    put('leftWrist', 15);
    put('rightWrist', 16);
    put('leftHip', 23);
    put('rightHip', 24);
    put('leftKnee', 25);
    put('rightKnee', 26);
    put('leftAnkle', 27);
    put('rightAnkle', 28);

    return map;
  }

  double _clamp01(num v) {
    final d = v.toDouble();
    if (d < 0) return 0;
    if (d > 1) return 1;
    return d;
  }
}
