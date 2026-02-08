// lib/logic/subject_tracker.dart
import 'package:flutter/material.dart';

/// 単一人物の「被写体ロック」用ゲート
/// - enroll(): 現在のランドマークからアンカー（位置・スケール）を作成
/// - filter(lm): アンカーからの乖離が大きいフレームを除外（null を返す）
///
/// lm は 0..1 正規化の BlazePose 準拠（11,12=肩 L/R, 23,24=腰 L/R が必要）
class SubjectTracker {
  bool _locked = false;

  // アンカー（ロール補正なしの素の座標でOK）
  Offset? _anchorCenter; // 肩腰の中心
  double? _anchorScale;  // 肩腰の距離（正規化）

  // 許容（必要に応じて微調整してください）
  final double posTol;   // 位置の許容（画面幅に対する比率）
  final double sclTol;   // スケールの許容（比率）
  final double emaAlpha; // アンカーの滑らか更新

  SubjectTracker({
    this.posTol = 0.18,   // 位置 18% 以内
    this.sclTol = 0.28,   // スケール 28% 以内
    this.emaAlpha = 0.15, // アンカーはやや鈍く追随（手ブレ吸収）
  });

  bool get isLocked => _locked;

  /// 対象を現在のランドマークでロック（または再ロック）
  bool enroll(List<Offset> lms01) {
    final c = _center(lms01);
    final s = _scale(lms01);
    if (c == null || s == null) return false;
    _anchorCenter = c;
    _anchorScale = s;
    _locked = true;
    return true;
  }

  /// ロック解除
  void clear() {
    _locked = false;
    _anchorCenter = null;
    _anchorScale = null;
  }

  /// ロック中：乖離が大きいフレームは null を返す（=無視）
  /// ロックしていない：そのまま通す
  List<Offset>? filter(List<Offset> lms01) {
    if (!_locked) return lms01;

    final c = _center(lms01);
    final s = _scale(lms01);
    if (c == null || s == null) return null;

    final ac = _anchorCenter!;
    final as_ = _anchorScale!;
    final posErr = (c - ac).distance;    // 0..~1
    final sclErr = (s - as_).abs();      // 0..~1

    final pass = posErr <= posTol && sclErr <= sclTol;

    // 合格したフレームではアンカーを緩やかに更新（被写体の自然な移動を追従）
    if (pass) {
      _anchorCenter = Offset(
        (1 - emaAlpha) * ac.dx + emaAlpha * c.dx,
        (1 - emaAlpha) * ac.dy + emaAlpha * c.dy,
      );
      _anchorScale = (1 - emaAlpha) * as_ + emaAlpha * s;
      return lms01;
    }
    return null;
  }

  // ---- helpers -------------------------------------------------------------
  Offset? _center(List<Offset> l) {
    if (l.length <= 24) return null;
    final ls = l[11], rs = l[12], lh = l[23], rh = l[24];
    if (!_ok(ls) || !_ok(rs) || !_ok(lh) || !_ok(rh)) return null;
    final sx = (ls.dx + rs.dx) / 2, sy = (ls.dy + rs.dy) / 2;
    final hx = (lh.dx + rh.dx) / 2, hy = (lh.dy + rh.dy) / 2;
    return Offset((sx + hx) / 2, (sy + hy) / 2);
  }

  double? _scale(List<Offset> l) {
    if (l.length <= 24) return null;
    final ls = l[11], rs = l[12], lh = l[23], rh = l[24];
    if (!_ok(ls) || !_ok(rs) || !_ok(lh) || !_ok(rh)) return null;
    final sx = (ls.dx + rs.dx) / 2, sy = (ls.dy + rs.dy) / 2;
    final hx = (lh.dx + rh.dx) / 2, hy = (lh.dy + rh.dy) / 2;
    final dx = sx - hx, dy = sy - hy;
    return (dx * dx + dy * dy).sqrt(); // ≒ 身体の縦サイズ（0..~1）
  }

  bool _ok(Offset p) => !(p.dx.isNaN || p.dy.isNaN);
}

extension on double {
  double sqrt() => MathHelper.sqrt(this);
}

class MathHelper {
  static double sqrt(double v) => v <= 0 ? 0 : v.abs().toDouble().sqrtInternal();
}

extension _Sqrt on double {
  double sqrtInternal() => (this).toDouble()._sqrtIter();
  double _sqrtIter() {
    double x = this;
    double r = x > 1 ? x : 1.0;
    for (int i = 0; i < 6; i++) {
      r = 0.5 * (r + x / r);
    }
    return r;
  }
}
