// lib/logic/squat_coach.dart
import 'dart:math' as math;

/// ---- 受け取り用：ランドマーク（MediaPipe/ML Kitの正規化座標を想定） ----
/// x,y は [0..1]。左端=0, 右端=1, 上=0, 下=1 の一般的な正規化座標系を想定。
class PoseLm {
  final double x, y;
  final double visibility; // 0..1
  const PoseLm(this.x, this.y, [this.visibility = 1.0]);
}

/// 必要なランドマークのインデックス（MediaPipe Pose準拠）
class LM {
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;       // あれば使う（無ければ footIndex を利用）
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;  // つま先
  static const int rightFootIndex = 32;
}

enum SquatState { idle, descend, bottom, ascend }

class SquatConfig {
  // スムージング
  final double emaAlpha; // 0.0..1.0 大きいほど追従性↑(デフォ 0.3)
  // 判定しきい値
  final double depthOk;         // 十分深いとみなすROM%（0..1） 例: 0.8
  final double torsoMaxDeg;     // 上体前傾の許容角（deg）      例: 45
  final double valgusRatioMin;  // 膝の左右距離 / 足首の左右距離 の最小比 例: 0.9
  final double asymKneeDeg;     // 左右膝角の許容差（deg）      例: 10
  final double heelLiftThresh;  // かかと浮き（足首y と つま先/踵y の差） 例: 0.02
  final int   minRepMillis;     // 最短レップ時間(ms) 例: 900ms

  const SquatConfig({
    this.emaAlpha = 0.3,
    this.depthOk = 0.80,
    this.torsoMaxDeg = 45.0,
    this.valgusRatioMin = 0.90,
    this.asymKneeDeg = 10.0,
    this.heelLiftThresh = 0.02,
    this.minRepMillis = 900,
  });
}

class SquatFeedback {
  final int reps;
  final double romPct;      // 0..1（現在の深さ%）
  final bool okDepth;
  final bool warnTorsoLean;
  final bool warnValgus;
  final bool warnHeelsUp;
  final bool warnAsym;
  final List<String> cues;  // 画面に出す短い指示
  const SquatFeedback({
    required this.reps,
    required this.romPct,
    required this.okDepth,
    required this.warnTorsoLean,
    required this.warnValgus,
    required this.warnHeelsUp,
    required this.warnAsym,
    required this.cues,
  });
}

/// スクワット・フォームコーチ本体
class SquatCoach {
  final SquatConfig cfg;
  SquatState _st = SquatState.idle;
  int _reps = 0;
  int _lastTopMs = 0; // 直近でトップに戻った時刻
  double _emaHipY = 0; // スムージング後のヒップ高さ（平均）
  double _emaKneeY = 0;
  double _emaShoulderX = 0, _emaShoulderY = 0;
  double _emaHipX = 0, _emaHipY2 = 0; // hipYは2つ使わず同じでもOKだが可読のため分離
  double _emaLeftKneeAngle = 180, _emaRightKneeAngle = 180;

  // キャリブレーション用：立位の基準（ヒップ高さ・膝高さ）
  bool _calibrated = false;
  double _standHipY = 0.5; // 立位ヒップ高さ
  double _kneeY = 0.7;     // 膝高さ（ROM下限側の基準）

  SquatCoach({this.cfg = const SquatConfig()});

  bool get calibrated => _calibrated;
  int get reps => _reps;
  SquatState get state => _st;

  /// 立位で1回呼んで基準を作る（起動直後/ユーザーに「正面を向いて立ってください」などの時に）
  void calibrate(List<PoseLm> lm) {
    final hipY = _avgY(lm, LM.leftHip, LM.rightHip);
    final kneeY = _avgY(lm, LM.leftKnee, LM.rightKnee);
    if (hipY == null || kneeY == null) return;
    _standHipY = hipY;
    _kneeY = kneeY;
    _emaHipY = hipY;
    _emaKneeY = kneeY;
    _calibrated = true;
  }

  /// 毎フレーム呼ぶ。nowMs は `DateTime.now().millisecondsSinceEpoch`
  SquatFeedback update(List<PoseLm> lm, int nowMs) {
    if (lm.length <= LM.rightFootIndex) {
      // 最低限の点が無ければ何もしない
      return _empty(nowMs);
    }

    // ---- 主要点抽出 & 可視性で信頼度チェック ----
    final leftHip = lm[LM.leftHip], rightHip = lm[LM.rightHip];
    final leftKnee = lm[LM.leftKnee], rightKnee = lm[LM.rightKnee];
    final leftAnkle = lm[LM.leftAnkle], rightAnkle = lm[LM.rightAnkle];
    final leftShoulder = lm[LM.leftShoulder], rightShoulder = lm[LM.rightShoulder];
    final leftFootIdx = lm[LM.leftFootIndex], rightFootIdx = lm[LM.rightFootIndex];
    final leftHeel = lm.length > LM.leftHeel ? lm[LM.leftHeel] : leftFootIdx;
    final rightHeel = lm.length > LM.rightHeel ? lm[LM.rightHeel] : rightFootIdx;

    // 有効でなければ前回値を返す
    if (!_visibleAll([leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle])) {
      return _empty(nowMs);
    }

    // ---- スムージング（EMA）----
    double ema(double prev, double x) => cfg.emaAlpha * x + (1 - cfg.emaAlpha) * prev;

    final hipYRaw = _avg2(leftHip.y, rightHip.y);
    final hipXRaw = _avg2(leftHip.x, rightHip.x);
    final kneeYRaw = _avg2(leftKnee.y, rightKnee.y);
    final shoulderXRaw = _avg2(leftShoulder.x, rightShoulder.x);
    final shoulderYRaw = _avg2(leftShoulder.y, rightShoulder.y);

    _emaHipY = _emaHipY == 0 ? hipYRaw : ema(_emaHipY, hipYRaw);
    _emaHipX = _emaHipX == 0 ? hipXRaw : ema(_emaHipX, hipXRaw);
    _emaKneeY = _emaKneeY == 0 ? kneeYRaw : ema(_emaKneeY, kneeYRaw);
    _emaShoulderX = _emaShoulderX == 0 ? shoulderXRaw : ema(_emaShoulderX, shoulderXRaw);
    _emaShoulderY = _emaShoulderY == 0 ? shoulderYRaw : ema(_emaShoulderY, shoulderYRaw);
    _emaHipY2 = _emaHipY;

    // 膝角（大腿-膝-下腿）を左右で算出
    final leftKneeDeg = _kneeAngleDeg(lm, isLeft: true);
    final rightKneeDeg = _kneeAngleDeg(lm, isLeft: false);
    _emaLeftKneeAngle = ema(_emaLeftKneeAngle, leftKneeDeg);
    _emaRightKneeAngle = ema(_emaRightKneeAngle, rightKneeDeg);

    // ---- ROM%（深さ） : 立位HipY→KneeY を1.0とした正規化（yは下向きが+想定）----
    if (!_calibrated) {
      calibrate(lm); // 立位に近い開始を想定して自動キャリブ
    }
    final denom = (_kneeY - _standHipY).abs().clamp(1e-4, 1.0);
    final romPct = ((_emaHipY - _standHipY) / denom).clamp(0.0, 1.2); // 1.0超はスナップで下げる
    final romPctClamped = math.min(romPct, 1.0);

    // ---- トルソー前傾 ----
    // ベクトル（Hip -> Shoulder）を縦基準と比較
    final dx = _emaShoulderX - _emaHipX;
    final dy = _emaShoulderY - _emaHipY2;
    // 縦線との差：atan2(|dx|, |dy|) を度に
    final torsoDeg = (math.atan2(dx.abs(), (dy.abs() + 1e-6)) * 180 / math.pi);
    final warnTorso = torsoDeg > cfg.torsoMaxDeg;

    // ---- ニーバルガス：両膝の横距離 / 両足首の横距離 ----
    final kneeDistX = (leftKnee.x - rightKnee.x).abs();
    final ankleDistX = (leftAnkle.x - rightAnkle.x).abs().clamp(1e-4, 1.0);
    final valgusRatio = kneeDistX / ankleDistX; // 小さいほど内側に寄っている
    final warnValgus = valgusRatio < cfg.valgusRatioMin;

    // ---- かかと浮き：足首y と 踵/つま先y の差 ----
    // 画面下方向が+なので、かかとが「上がる」と ankle.y が heel/footIndex より小さくなる傾向。
    bool heelUpOne(PoseLm ankle, PoseLm heel, PoseLm toe) {
      final refY = math.min(heel.y, toe.y); // 踵とつま先のうち上にある方
      return (refY - ankle.y) > cfg.heelLiftThresh; // refY(足) > ankle(足首) で上がっている
    }
    final warnHeelL = heelUpOne(leftAnkle, leftHeel, leftFootIdx);
    final warnHeelR = heelUpOne(rightAnkle, rightHeel, rightFootIdx);
    final warnHeels = warnHeelL || warnHeelR;

    // ---- 左右差（膝角）----
    final warnAsym = (_emaLeftKneeAngle - _emaRightKneeAngle).abs() > cfg.asymKneeDeg;

    // ---- FSM：レップ確定 ----
    // Idle(立位) -> Descend(下降) -> Bottom -> Ascend(上昇) -> Idle 戻りで rep++
    // 開始条件：少しでも沈み込み（romPct > 0.05 など）
    final t = nowMs;
    switch (_st) {
      case SquatState.idle:
        if (romPctClamped > 0.05) _st = SquatState.descend;
        break;
      case SquatState.descend:
        if (romPctClamped > 0.98) _st = SquatState.bottom; // 最深近辺
        break;
      case SquatState.bottom:
        if (romPctClamped < 0.95) _st = SquatState.ascend;
        break;
      case SquatState.ascend:
        if (romPctClamped < 0.06) {
          // 上に戻った＝トップ
          if (t - _lastTopMs >= cfg.minRepMillis) {
            _reps++;
          }
          _lastTopMs = t;
          _st = SquatState.idle;
        }
        break;
    }

    // ---- キュー生成 ----
    final cues = <String>[];
    final okDepth = romPctClamped >= cfg.depthOk;
    if (_st == SquatState.bottom && !okDepth) cues.add('もう少し深く');
    if (warnValgus) cues.add('膝をつま先の向きに');
    if (warnTorso) cues.add('前傾しすぎ：胸を張る');
    if (warnHeels) cues.add('かかとを床に');
    if (warnAsym)  cues.add('左右の膝角をそろえる');

    return SquatFeedback(
      reps: _reps,
      romPct: romPctClamped,
      okDepth: okDepth,
      warnTorsoLean: warnTorso,
      warnValgus: warnValgus,
      warnHeelsUp: warnHeels,
      warnAsym: warnAsym,
      cues: cues,
    );
  }

  // ---- 内部ユーティリティ ----
  SquatFeedback _empty(int _) => SquatFeedback(
    reps: _reps,
    romPct: 0,
    okDepth: false,
    warnTorsoLean: false,
    warnValgus: false,
    warnHeelsUp: false,
    warnAsym: false,
    cues: const [],
  );

  bool _visibleAll(List<PoseLm> xs) => xs.every((p) => p.visibility > 0.5);

  double? _avgY(List<PoseLm> lm, int a, int b) {
    final la = lm[a], lb = lm[b];
    if (la.visibility <= 0.5 || lb.visibility <= 0.5) return null;
    return (la.y + lb.y) / 2;
    }

  double _avg2(double a, double b) => (a + b) / 2;

  // 大腿(hip->knee) と 下腿(knee->ankle) の角度（膝内角、伸展=約180°）
  double _kneeAngleDeg(List<PoseLm> lm, {required bool isLeft}) {
    final hip = lm[isLeft ? LM.leftHip : LM.rightHip];
    final knee = lm[isLeft ? LM.leftKnee : LM.rightKnee];
    final ankle = lm[isLeft ? LM.leftAnkle : LM.rightAnkle];
    final v1x = hip.x - knee.x, v1y = hip.y - knee.y;
    final v2x = ankle.x - knee.x, v2y = ankle.y - knee.y;
    final dot = v1x * v2x + v1y * v2y;
    final n1 = math.sqrt(v1x * v1x + v1y * v1y) + 1e-6;
    final n2 = math.sqrt(v2x * v2x + v2y * v2y) + 1e-6;
    final cos = (dot / (n1 * n2)).clamp(-1.0, 1.0);
    final deg = math.acos(cos) * 180 / math.pi;
    return deg; // 180 に近いほど伸び、90 付近がしゃがみ
  }
}
