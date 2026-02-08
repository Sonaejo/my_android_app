// lib/logic/pose_logic.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

/// Pose処理のフェーズ共通定義
enum PosePhase { searching, calibrating, ready, running }

/// 1フレーム分の入力（ランドマークとタイムスタンプ）
/// - lm01: 画像正規化座標（0..1）でのランドマークリスト（BlazePose等を想定）
/// - timestampMs: 省略時は現在時刻
class PoseFrame {
  final List<Offset> lm01;
  final int timestampMs;
  const PoseFrame(this.lm01, {int? timestampMs})
      : timestampMs = timestampMs ?? 0;
}

/// 画面側に返す共通状態
/// - reps: 累計回数
/// - progress: 0..1 の主要進捗（スクワット=ROM, 腕立て=Depth 等）
/// - phase: 現在のフェーズ
/// - calibrated: キャリブレーション完了か
/// - warns: 汎用的な警告フラグ（キーは 'sag' 'valgus' など）
/// - cues: ユーザー提示用の短文キュー
/// - metrics: 任意の数値メトリクス（'torsoDeg' 'bodySagDeg' 'leftElbowDeg' 等）
/// - extras: 将来拡張やデバッグ向けの任意データ置き場
class PoseState {
  final int reps;
  final double progress; // 0..1
  final PosePhase phase;
  final bool calibrated;
  final Map<String, bool> warns;
  final List<String> cues;
  final Map<String, double> metrics;
  final Map<String, Object?> extras;

  const PoseState({
    required this.reps,
    required this.progress,
    required this.phase,
    required this.calibrated,
    required this.warns,
    required this.cues,
    required this.metrics,
    required this.extras,
  });

  PoseState copyWith({
    int? reps,
    double? progress,
    PosePhase? phase,
    bool? calibrated,
    Map<String, bool>? warns,
    List<String>? cues,
    Map<String, double>? metrics,
    Map<String, Object?>? extras,
  }) {
    return PoseState(
      reps: reps ?? this.reps,
      progress: progress ?? this.progress,
      phase: phase ?? this.phase,
      calibrated: calibrated ?? this.calibrated,
      warns: warns ?? this.warns,
      cues: cues ?? this.cues,
      metrics: metrics ?? this.metrics,
      extras: extras ?? this.extras,
    );
  }

  static const empty = PoseState(
    reps: 0,
    progress: 0.0,
    phase: PosePhase.searching,
    calibrated: false,
    warns: const {},
    cues: const [],
    metrics: const {},
    extras: const {},
  );
}

/// 各種目ロジックが実装すべき共通IF
abstract class PoseLogic {
  /// 識別用ラベル（'squat', 'pushup' など）
  String get id;

  /// 状態をリセット
  void reset();

  /// 1フレーム処理して PoseState を返す
  PoseState process(PoseFrame frame);
}

/// ===== ヘルパ群（共通ユーティリティ） ======================================

/// 0..1 にクランプ
double clamp01(double v) => v.clamp(0.0, 1.0);

/// NaNかどうか
bool _isNaN(double v) => v.isNaN;

/// 有効なランドマークか
bool validPoint(Offset p) => !(_isNaN(p.dx) || _isNaN(p.dy));

/// 3点（a-b-c）から内角（度）を計算
double angleDeg(Offset a, Offset b, Offset c) {
  final v1 = vmath.Vector2(a.dx - b.dx, a.dy - b.dy);
  final v2 = vmath.Vector2(c.dx - b.dx, c.dy - b.dy);
  final dot = v1.dot(v2);
  final len = v1.length * v2.length;
  if (len == 0) return 0.0;
  final cosv = (dot / len).clamp(-1.0, 1.0);
  return vmath.degrees(math.acos(cosv));
}

/// 2点の距離
double dist(Offset a, Offset b) {
  final dx = a.dx - b.dx, dy = a.dy - b.dy;
  return math.sqrt(dx * dx + dy * dy);
}

/// 単純EMA（prevがnull/NaNの場合はxで初期化）
double ema(double? prev, double x, double alpha) {
  if (prev == null || prev.isNaN) return x;
  return alpha * x + (1 - alpha) * prev;
}

/// 水平/垂直のデルタから角度（度）
/// - 例：肩中心と腰中心のdx,dyから体幹の「落ち込み角」等を算出
double angleFromDxDy(double dx, double dy) {
  return math.atan2(dx.abs(), (dy.abs() + 1e-6)) * 180 / math.pi;
}

/// BlazePose 等のランドマーク index 定数（必要分のみ）
/// 参考: https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
class Lm {
  // 顔や膝なども必要になれば随時追加
  static const int leftShoulder  = 11;
  static const int rightShoulder = 12;
  static const int leftElbow     = 13;
  static const int rightElbow    = 14;
  static const int leftWrist     = 15;
  static const int rightWrist    = 16;
  static const int leftHip       = 23;
  static const int rightHip      = 24;
  static const int leftKnee      = 25;
  static const int rightKnee     = 26;
  static const int leftAnkle     = 27;
  static const int rightAnkle    = 28;
}

/// 必須ランドマークが存在するか（indexの最大値まで）
/// - minIndex: 要求する最大インデックス（例：腰R=24 なら 24）
/// - alsoValid: すべて validPoint() を満たす必要があるか
bool hasRequiredLandmarks(List<Offset> l, int minIndex, {bool alsoValid = true}) {
  if (l.length <= minIndex) return false;
  if (!alsoValid) return true;
  for (int i = 0; i <= minIndex; i++) {
    final p = l[i];
    if (!validPoint(p)) return false;
  }
  return true;
}

/// ===== アダプタ実装の例（参考：別ファイル推奨） =============================
///
/// 既存の種目ロジック（例：PushupLogic / SquatLogic）を共通IFに載せる場合、
/// 下記のようなアダプタを **別ファイル** に作るのが循環依存を避けるコツです。
///
/// ```dart
/// // lib/logic/adapters/pushup_adapter.dart
/// import 'package:flutter/material.dart';
/// import '../pose_logic.dart';
/// import '../pushup_logic.dart';
///
/// class PushupAdapter implements PoseLogic {
///   final PushupLogic _inner;
///   PushupAdapter(this._inner);
///
///   @override
///   String get id => 'pushup';
///
///   @override
///   void reset() => _inner.reset();
///
///   @override
///   PoseState process(PoseFrame frame) {
///     final s = _inner.process(frame.lm01); // PushupState
///     return PoseState(
///       reps: s.reps,
///       progress: s.depthPct, // 0..1
///       phase: PosePhase.running, // 腕立ては基本ランタイム運用
///       calibrated: true,        // 必要に応じて調整
///       warns: {
///         'sag': s.warnSag,
///         'asym': s.warnAsym,
///         'range': s.warnRange,
///       },
///       cues: s.cues,
///       metrics: {
///         'bodySagDeg': s.bodySagDeg,
///       },
///       extras: const {},
///     );
///   }
/// }
/// ```
///
/// スクワット側も同様に、`romPct` や `torsoDeg` を `progress` / `metrics` に
/// マッピングすれば、画面側は `PoseLogic` 統一で扱えるようになります。
