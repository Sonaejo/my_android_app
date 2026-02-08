import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

/// 画面側へ返す状態（腕立て）
class PushupState {
  final int reps;
  final double depthPct;     // 0..1（表示用に平滑化済み）
  final double bodySagDeg;   // 体幹の落ち込み角（deg）
  final bool warnSag;        // 体幹が落ちている
  final bool warnAsym;       // 左右差
  final bool warnRange;      // 可動域が浅い
  final List<String> cues;   // 提示キュー

  // ★ 追加：セッション情報
  final int elapsedMs;       // セッション開始からの経過ミリ秒
  final double caloriesKcal; // 累積消費カロリー（kcal）

  const PushupState({
    required this.reps,
    required this.depthPct,
    required this.bodySagDeg,
    required this.warnSag,
    required this.warnAsym,
    required this.warnRange,
    required this.cues,
    required this.elapsedMs,
    required this.caloriesKcal,
  });
}

/// 正面/横どちらでも使える Push-up ロジック
class PushupLogic {
  // ===== 定数 ================================================================
  static const double _emaAlphaPos   = 0.35;
  static const double _emaAlphaDeg   = 0.45;
  static const double _emaAlphaDepth = 0.35;

  static const double _elbowMaxDeg = 175.0;
  static const double _elbowMinDeg = 85.0;

  static const double _wChest = 0.6;
  static const double _wElbow = 0.4;

  static const double _bottomTh = 0.70;
  static const double _topTh    = 0.20;
  static const int    _minRepMs = 600;

  static const double _sagMaxDeg  = 12.0;
  static const double _asymMaxDeg = 12.0;

  static const double _needRange = 0.06;
  static const double _chestLerp = 0.35;
  static const double _eps       = 1e-6;

  // ★ 1レップあたりの近似カロリー
  static const double _kcalPerRep = 0.5;

  // ===== 内部状態 ============================================================
  int _reps = 0;
  bool _hitBottom = false;
  int _lastTopMs = 0;

  // セッション計時／カロリー
  int _sessionStartMs = 0;
  int _elapsedMs = 0;
  double _caloriesKcal = 0.0;

  // EMA
  double _emaShoulderY = double.nan;
  double _emaHipY      = double.nan;
  double _emaLeftElbowDeg  = double.nan;
  double _emaRightElbowDeg = double.nan;

  // キャリブ
  double _topChestY = double.nan;
  double _bottomChestY = double.nan;
  bool   _calibrated = false;

  // 出力寄せ
  double _depth = 0.0;
  double _depthEma = 0.0;
  double _sagDeg = 0.0;
  bool _warnSag = false, _warnAsym = false, _warnRange = false;

  double _lastBottomDepth = 0.0;

  // ===== パブリックAPI =======================================================
  void reset() {
    _reps = 0;
    _hitBottom = false;
    _lastTopMs = 0;

    // ★ セッション開始をここで刻む（タイマーが進む）
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    _elapsedMs = 0;
    _caloriesKcal = 0.0;

    _emaShoulderY = double.nan;
    _emaHipY      = double.nan;
    _emaLeftElbowDeg  = double.nan;
    _emaRightElbowDeg = double.nan;

    _topChestY = double.nan;
    _bottomChestY = double.nan;
    _calibrated = false;

    _depth = 0.0;
    _depthEma = 0.0;
    _sagDeg = 0.0;
    _warnSag = _warnAsym = _warnRange = false;

    _lastBottomDepth = 0.0;
  }

  PushupState process(List<Offset> lm01) {
    // ★ 遅延初期化（resetを呼ばなくても動く保険）
    if (_sessionStartMs == 0) {
      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _elapsedMs = now - _sessionStartMs;

    if (!_hasRequired(lm01)) {
      return _build(_calibrated ? const [] : const ['最初の1〜2回は通常フォームで上下してね']);
    }

    // 主要点
    final ls = lm01[11], rs = lm01[12];
    final le = lm01[13], re = lm01[14];
    final lw = lm01[15], rw = lm01[16];
    final lh = lm01[23], rh = lm01[24];

    // ---------- ロール補正 ----------
    final shoulderMid = Offset((ls.dx + rs.dx) / 2, (ls.dy + rs.dy) / 2);
    final rollRad = math.atan2(rs.dy - ls.dy, rs.dx - ls.dx);
    Offset rot(Offset p) {
      final dx = p.dx - shoulderMid.dx;
      final dy = p.dy - shoulderMid.dy;
      final c = math.cos(-rollRad), s = math.sin(-rollRad);
      return Offset(
        shoulderMid.dx + dx * c - dy * s,
        shoulderMid.dy + dx * s + dy * c,
      );
    }

    final lsR = rot(ls), rsR = rot(rs);
    final leR = rot(le), reR = rot(re);
    final lwR = rot(lw), rwR = rot(rw);
    final lhR = rot(lh), rhR = rot(rh);

    // ---------- 胸の代理点 ----------
    final shMidR  = Offset((lsR.dx + rsR.dx) / 2, (lsR.dy + rsR.dy) / 2);
    final hipMidR = Offset((lhR.dx + rhR.dx) / 2, (lhR.dy + rhR.dy) / 2);
    final chestR  = Offset(
      shMidR.dx + (hipMidR.dx - shMidR.dx) * _chestLerp,
      shMidR.dy + (hipMidR.dy - shMidR.dy) * _chestLerp,
    );
    final chestY = chestR.dy;

    // ---------- 肘角 ----------
    double elbowDeg(Offset shoulder, Offset elbow, Offset wrist) {
      final v1 = vmath.Vector2(shoulder.dx - elbow.dx, shoulder.dy - elbow.dy);
      final v2 = vmath.Vector2(wrist.dx - elbow.dx, wrist.dy - elbow.dy);
      final dot = v1.dot(v2);
      final len = v1.length * v2.length;
      if (len == 0) return 180;
      final cosv = (dot / len).clamp(-1.0, 1.0);
      return vmath.degrees(math.acos(cosv));
    }
    final leftElbowDeg  = elbowDeg(ls, le, lw);
    final rightElbowDeg = elbowDeg(rs, re, rw);

    // ===== EMA 更新 ==========================================================
    double _ema(double prev, double x, double a) => prev.isNaN ? x : (a * x + (1 - a) * prev);
    _emaShoulderY      = _ema(_emaShoulderY, (lsR.dy + rsR.dy) / 2, _emaAlphaPos);
    _emaHipY           = _ema(_emaHipY,      (lhR.dy + rhR.dy) / 2, _emaAlphaPos);
    _emaLeftElbowDeg   = _ema(_emaLeftElbowDeg,  leftElbowDeg,  _emaAlphaDeg);
    _emaRightElbowDeg  = _ema(_emaRightElbowDeg, rightElbowDeg, _emaAlphaDeg);

    // ===== A) 胸の上下ベース Depth（自動キャリブ） ==========================
    if (_topChestY.isNaN) _topChestY = chestY;
    if (_bottomChestY.isNaN) _bottomChestY = chestY;
    _topChestY    = (_topChestY    * 0.95) + (math.min(_topChestY, chestY)    * 0.05);
    _bottomChestY = (_bottomChestY * 0.95) + (math.max(_bottomChestY, chestY) * 0.05);

    final chestRange = (_bottomChestY - _topChestY).abs();
    _calibrated = chestRange > _needRange;

    double depthChest = 0.0;
    if (_calibrated) {
      final denom = (chestRange).clamp(0.02, 1.0);
      depthChest = ((chestY - _topChestY) / denom).clamp(0.0, 1.0);
    }

    // ===== B) 肘角ベース Depth ===============================================
    final meanElbowDeg = (_emaLeftElbowDeg + _emaRightElbowDeg) / 2.0;
    final denomElbow = (_elbowMaxDeg - _elbowMinDeg).abs().clamp(1e-6, 1e9);
    final depthElbow = ((_elbowMaxDeg - meanElbowDeg) / denomElbow).clamp(0.0, 1.0);

    // ===== C) 合成 Depth =====================================================
    final depthHybrid = (_wChest * depthChest) + (_wElbow * depthElbow);
    _depth = depthHybrid;
    _depthEma = _ema(_depthEma, _depth, _emaAlphaDepth).clamp(0.0, 1.0);

    // ===== 体幹落ち込み角 ====================================================
    final dx = (shMidR.dx - hipMidR.dx).abs();
    final dy = (hipMidR.dy - shMidR.dy).abs() + _eps;
    _sagDeg = math.atan2(dx, dy) * 180 / math.pi;
    _warnSag = _sagDeg > _sagMaxDeg;

    // ===== 左右差 ============================================================
    _warnAsym = (_emaLeftElbowDeg - _emaRightElbowDeg).abs() > _asymMaxDeg;

    // ===== カウント（胸ベース主条件） =======================================
    final useDepthForCount = depthChest > 0 ? depthChest : _depthEma;
    if (!_hitBottom && useDepthForCount >= _bottomTh) {
      _hitBottom = true;
      _lastBottomDepth = useDepthForCount;
    }
    if (_hitBottom && useDepthForCount <= _topTh) {
      if (now - _lastTopMs >= _minRepMs && depthElbow >= 0.35) {
        _reps++;
        _caloriesKcal = _reps * _kcalPerRep;   // ★ レップ→カロリー更新
      }
      _lastTopMs = now;
      _hitBottom = false;
    }

    // ===== 可動域が浅いか ====================================================
    _warnRange = (_lastBottomDepth < 0.80) && _calibrated;

    // ===== キュー =============================================================
    final cues = <String>[];
    if (!_calibrated) cues.add('最初の1〜2回は通常フォームで上下してね');
    if (_hitBottom && _depthEma < 0.85) cues.add('胸を床に近づける');
    if (_warnSag)   cues.add('体幹を固める（腰を落とさない）');
    if (_warnAsym)  cues.add('左右均等に押す');
    if (_warnRange) cues.add('可動域をもう少し広く');

    return _build(cues);
  }

  // ===== ヘルパ ==============================================================
  bool _hasRequired(List<Offset> l) {
    if (l.length <= 24) return false;
    bool ok(Offset p) => !(p.dx.isNaN || p.dy.isNaN);
    return ok(l[11]) && ok(l[12]) &&
           ok(l[13]) && ok(l[14]) &&
           ok(l[15]) && ok(l[16]) &&
           ok(l[23]) && ok(l[24]);
  }

  PushupState _build(List<String> cues) => PushupState(
    reps: _reps,
    depthPct: _depthEma.clamp(0.0, 1.0),
    bodySagDeg: _sagDeg,
    warnSag: _warnSag,
    warnAsym: _warnAsym,
    warnRange: _warnRange,
    cues: cues,
    elapsedMs: _elapsedMs,            // ★ 追加
    caloriesKcal: _caloriesKcal,      // ★ 追加
  );
}
