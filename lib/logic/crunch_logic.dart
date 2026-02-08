// lib/logic/crunch_logic.dart
import 'dart:math' as math;
import 'dart:ui' show Offset;

/// 画面側へ返す状態（クランチ）
class CrunchState {
  final int reps;
  final double depthPct;     // 0..1（可動域の進み具合）
  final double coreDeg;      // 体幹角度（肩-腰-膝）deg
  final bool warnSag;        // フォーム警告（例: 起き上がり不足など）
  final List<String> cues;   // フィードバックキュー

  /// セッション開始からの経過時間（ミリ秒）
  final int elapsedMs;

  /// 累積消費カロリー（kcal）
  final double caloriesKcal;

  const CrunchState({
    required this.reps,
    required this.depthPct,
    required this.coreDeg,
    required this.warnSag,
    required this.cues,
    required this.elapsedMs,
    required this.caloriesKcal,
  });
}

/// 正面/斜め上から見た「上体起こし」用ロジック
///
/// 入力: BlazePose 準拠の 0..1 正規化ランドマーク（List<Offset> lm01, index 33想定）
///
/// 主に使う点:
/// - 肩: 11,12
/// - 腰: 23,24
/// - 膝: 25,26
class CrunchLogic {
  // ===== 調整用しきい値 ======================================================

  // 肩-腰-膝の角度（coreDeg）がこのあたりなら「ほぼ寝ている」状態とみなす
  static const double _coreStraightDeg = 170.0;

  // このあたりなら「かなり起き上がっている」状態とみなす（深いクランチ）
  static const double _coreBentDeg = 100.0;

  // レップ判定用の閾値（push-up と同じ思想）
  static const double _bottomTh = 0.70; // 下（起き上がり）とみなす深さ
  static const double _topTh    = 0.25; // 上（戻り）とみなす深さ
  static const int    _minRepMs = 500;  // 1レップの最短時間（早すぎ抑制）

  // EMAの係数（0に近いほどゆっくり、1に近いほど生値に近い）
  static const double _emaDepthAlpha = 0.35;
  static const double _emaCoreAlpha  = 0.40;

  // 1レップあたりの概算カロリー（必要に応じて調整）
  static const double _kcalPerRep = 0.4;

  // ===== 内部状態 ============================================================

  int _reps = 0;
  bool _hitBottom = false;
  int _lastTopMs = 0;

  // セッション計時／カロリー
  int _sessionStartMs = 0;
  int _elapsedMs = 0;
  double _caloriesKcal = 0.0;

  // Depth & core 角度
  double _depthRaw = 0.0;   // 生の depth
  double _depthEma = 0.0;   // 平滑化 depth
  double _coreDeg = 180.0;  // 肩-腰-膝角（生）
  double _coreDegEma = 180.0;

  bool _warnSag = false;

  // ===== 公開API =============================================================

  void reset() {
    _reps = 0;
    _hitBottom = false;
    _lastTopMs = 0;

    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    _elapsedMs = 0;
    _caloriesKcal = 0.0;

    _depthRaw = 0.0;
    _depthEma = 0.0;
    _coreDeg = 180.0;
    _coreDegEma = 180.0;
    _warnSag = false;
  }

  /// メイン処理
  ///
  /// [lm01] は 0..1 正規化された BlazePose 33点を想定。
  CrunchState process(List<Offset> lm01) {
    // 遅延初期化（resetを呼ばなくても動く保険）
    if (_sessionStartMs == 0) {
      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _elapsedMs = now - _sessionStartMs;

    if (!_hasRequired(lm01)) {
      return _buildState(
        cues: const ['カメラに上半身と腰・膝が映るように調整してね'],
      );
    }

    // ================== 主要点抽出 ==========================================
    final ls = lm01[11]; // leftShoulder
    final rs = lm01[12]; // rightShoulder
    final lh = lm01[23]; // leftHip
    final rh = lm01[24]; // rightHip
    final lk = lm01[25]; // leftKnee
    final rk = lm01[26]; // rightKnee

    final shoulder = _mid(ls, rs);
    final hip      = _mid(lh, rh);
    final knee     = _mid(lk, rk);

    // ================== 体幹角度（coreDeg） ==================================
    final coreDegRaw = _angleDeg(shoulder, hip, knee); // 180に近いほど伸びている
    _coreDegEma = _ema(_coreDegEma, coreDegRaw, _emaCoreAlpha);
    _coreDeg = _coreDegEma;

    // ================== 深さ（depth）計算 ====================================
    //
    // coreDeg が _coreStraightDeg 付近 → depth ≒ 0（寝ている）
    // coreDeg が _coreBentDeg     付近 → depth ≒ 1（しっかり起き上がり）
    final denom = (_coreStraightDeg - _coreBentDeg).abs().clamp(1e-6, 1e9);
    final depthRaw = ((_coreStraightDeg - _coreDeg) / denom).clamp(0.0, 1.0);
    _depthEma = _ema(_depthEma, depthRaw, _emaDepthAlpha);
    _depthRaw = depthRaw;

    // ================== フォーム警告 ========================================
    // ここでは「深さ不足」を warnSag として扱う（あまり起き上がれていない）
    _warnSag = _depthEma < 0.5;

    // ================== レップカウント ======================================
    final useDepthForCount = _depthEma;

    if (!_hitBottom && useDepthForCount >= _bottomTh) {
      // 下（起き上がり）到達
      _hitBottom = true;
    }

    if (_hitBottom && useDepthForCount <= _topTh) {
      // 上（戻り）へ戻ってきた
      if (now - _lastTopMs >= _minRepMs) {
        _reps++;
        _caloriesKcal = _reps * _kcalPerRep;
      }
      _lastTopMs = now;
      _hitBottom = false;
    }

    // ================== キュー ==============================================
    final cues = <String>[];
    if (_depthEma < 0.5) {
      cues.add('しっかり上体を起こしてみよう');
    }
    if (_coreDeg > _coreStraightDeg - 5) {
      cues.add('腰を反りすぎないように注意');
    }

    return _buildState(cues: cues);
  }

  // ===== 内部ヘルパ ==========================================================

  bool _hasRequired(List<Offset> l) {
    if (l.length <= 26) return false;
    bool ok(Offset p) => !(p.dx.isNaN || p.dy.isNaN);
    return ok(l[11]) && ok(l[12]) && // shoulders
           ok(l[23]) && ok(l[24]) && // hips
           ok(l[25]) && ok(l[26]);   // knees
  }

  Offset _mid(Offset a, Offset b) => Offset(
        (a.dx + b.dx) / 2.0,
        (a.dy + b.dy) / 2.0,
      );

  double _angleDeg(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);

    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final na = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final nc = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
    if (na == 0 || nc == 0) return 180.0;

    final cosv = (dot / (na * nc)).clamp(-1.0, 1.0);
    return math.acos(cosv) * 180.0 / math.pi;
  }

  double _ema(double prev, double x, double alpha) =>
      alpha * x + (1 - alpha) * prev;

  CrunchState _buildState({required List<String> cues}) {
    return CrunchState(
      reps: _reps,
      depthPct: _depthEma.clamp(0.0, 1.0),
      coreDeg: _coreDeg,
      warnSag: _warnSag,
      cues: cues,
      elapsedMs: _elapsedMs,
      caloriesKcal: _caloriesKcal,
    );
  }
}
