import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

class SquatState {
  final int reps;
  final String phase;
  final double romPct;
  final double torsoDeg;
  final bool warnTorso;
  final bool warnValgus;
  final bool warnAsym;
  final List<String> cues;
  final bool calibrated;
  final int elapsedMs;
  final double caloriesKcal;

  const SquatState({
    required this.reps,
    required this.phase,
    required this.romPct,
    required this.torsoDeg,
    required this.warnTorso,
    required this.warnValgus,
    required this.warnAsym,
    required this.cues,
    required this.calibrated,
    required this.elapsedMs,
    required this.caloriesKcal,
  });
}

class SquatLogic {
  static const double _emaAlpha = 0.30;
  static const double _depthOk = 0.80;
  static const double _torsoMaxDeg = 45.0;
  static const double _valgusRatioMin = 0.90;
  static const double _asymKneeDeg = 10.0;
  static const int _minRepMillis = 900;

  static const int _standHoldFramesBase = 12;
  static const double _standMargin = 0.06;
  static const double _kneeStraightDeg = 160.0;

  static const int _dropResetFrames = 15;
  static const double _minBodyHeight = 0.55;
  static const double _minBodyTop = 0.05;
  static const double _maxBodyBottom = 0.95;

  static const double _bottomThreshold = 0.85;
  static const double _topThreshold = 0.08;

  // ★ 1レップあたりのカロリー
  static const double _kcalPerRep = 0.7;

  int _reps = 0;
  String _phase = 'searching';
  bool _calibrated = false;

  int _sessionStartMs = 0;
  int _elapsedMs = 0;
  double _caloriesKcal = 0.0;

  double _standHipY = 0.5;
  double _kneeY = 0.7;

  double _emaHipY = 0, _emaKneeY = 0, _emaHipX = 0, _emaShoulderX = 0, _emaShoulderY = 0;
  double _emaLeftKneeDeg = 180, _emaRightKneeDeg = 180;

  int _standingFrames = 0;
  int _fullBodyFrames = 0;
  int _invalidFrames = 0;

  double _romPct = 0;
  double _torsoDeg = 0;
  bool _warnTorso = false;
  bool _warnValgus = false;
  bool _warnAsym = false;

  double _fpsEstimate = 30.0;

  bool _hitBottom = false;
  int _lastRepMs = 0;

  SquatState process(List<Offset> lm01) {
    if (_sessionStartMs == 0) {
      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    }
    _elapsedMs = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;

    final bool validRequired = _hasRequired(lm01);
    final bool fullBody = validRequired && _isFullBodyVisible(lm01);

    if (!validRequired) {
      _invalidFrames++;
      if (_invalidFrames >= _dropResetFrames) {
        _resetToSearching();
      }
      return _buildState(const []);
    }
    _invalidFrames = 0;

    if (!_calibrated) {
      if (fullBody) {
        _fullBodyFrames++;
        _phase = 'calibrating';
        final int need = (_standHoldFramesBase * (30.0 / _fpsEstimate).clamp(0.5, 2.0)).round();
        if (_fullBodyFrames >= need) {
          return _calibrateIfStanding(lm01);
        }
      } else {
        _fullBodyFrames = 0;
        _phase = 'searching';
      }
      return _buildState(const []);
    }

    return _updateAndEval(lm01, fullBody: fullBody);
  }

  void resetAll() => _resetToSearching();

  SquatState _calibrateIfStanding(List<Offset> l) {
    final ls = l[11], rs = l[12];
    final lh = l[23], rh = l[24];
    final lk = l[25], rk = l[26];
    final la = l[27], ra = l[28];

    double avgX(Offset a, Offset b) => (a.dx + b.dx) / 2;
    double avgY(Offset a, Offset b) => (a.dy + b.dy) / 2;

    final double hipYRaw = avgY(lh, rh);
    final double kneeYRaw = avgY(lk, rk);
    final double hipXRaw = avgX(lh, rh);
    final double shXRaw = avgX(ls, rs);
    final double shYRaw = avgY(ls, rs);

    final double leftKneeDeg  = _kneeAngleDeg(lh, lk, la);
    final double rightKneeDeg = _kneeAngleDeg(rh, rk, ra);

    if (_isStanding(
      hipY: hipYRaw,
      kneeY: kneeYRaw,
      kneeLeftDeg: leftKneeDeg,
      kneeRightDeg: rightKneeDeg,
    )) {
      _standingFrames++;
      final int need = (_standHoldFramesBase * (30.0 / _fpsEstimate).clamp(0.5, 2.0)).round();
      if (_standingFrames >= need) {
        _standHipY = hipYRaw;
        _kneeY = kneeYRaw;
        _emaHipY = hipYRaw; _emaKneeY = kneeYRaw; _emaHipX = hipXRaw;
        _emaShoulderX = shXRaw; _emaShoulderY = shYRaw;

        _calibrated = true;
        _phase = 'ready';
        _standingFrames = 0;
        _fullBodyFrames = 0;
        _hitBottom = false;

        _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
        _elapsedMs = 0;
        _caloriesKcal = 0.0;
      }
    } else {
      _standingFrames = 0;
    }
    return _buildState(const []);
  }

  SquatState _updateAndEval(List<Offset> l, {required bool fullBody}) {
    final ls = l[11], rs = l[12];
    final lh = l[23], rh = l[24];
    final lk = l[25], rk = l[26];
    final la = l[27], ra = l[28];

    double avgX(Offset a, Offset b) => (a.dx + b.dx) / 2;
    double avgY(Offset a, Offset b) => (a.dy + b.dy) / 2;

    final double hipYRaw = avgY(lh, rh);
    final double kneeYRaw = avgY(lk, rk);
    final double hipXRaw = avgX(lh, rh);
    final double shXRaw = avgX(ls, rs);
    final double shYRaw = avgY(ls, rs);

    final double leftKneeDeg  = _kneeAngleDeg(lh, lk, la);
    final double rightKneeDeg = _kneeAngleDeg(rh, rk, ra);

    double ema(double prev, double x) => _emaAlpha * x + (1 - _emaAlpha) * prev;
    double _limitDelta(double prev, double next, double maxDelta) {
      final d = next - prev;
      if (d.abs() > maxDelta) return prev + d.sign * maxDelta;
      return next;
    }

    final double kneeLFiltered = _limitDelta(_emaLeftKneeDeg, leftKneeDeg, 20);
    final double kneeRFiltered = _limitDelta(_emaRightKneeDeg, rightKneeDeg, 20);

    _emaHipY = ema(_emaHipY, hipYRaw);
    _emaKneeY = ema(_emaKneeY, kneeYRaw);
    _emaHipX = ema(_emaHipX, hipXRaw);
    _emaShoulderX = ema(_emaShoulderX, shXRaw);
    _emaShoulderY = ema(_emaShoulderY, shYRaw);
    _emaLeftKneeDeg  = _emaLeftKneeDeg == 180 ? leftKneeDeg  : ema(_emaLeftKneeDeg,  kneeLFiltered);
    _emaRightKneeDeg = _emaRightKneeDeg == 180 ? rightKneeDeg : ema(_emaRightKneeDeg, kneeRFiltered);

    final double denom = (_kneeY - _standHipY).abs().clamp(1e-4, 1.0);
    final double romRaw = ((_emaHipY - _standHipY) / denom);
    _romPct = _limitDelta(_romPct, romRaw, 0.15).clamp(0.0, 1.2);
    final double romClamped = _romPct > 1.0 ? 1.0 : _romPct;

    _fpsEstimate = (_fpsEstimate * 0.95) + (30.0 * 0.05);

    final double dx = (_emaShoulderX - _emaHipX).abs();
    final double dy = (_emaShoulderY - _emaHipY).abs() + 1e-6;
    _torsoDeg = math.atan2(dx, dy) * 180 / math.pi;
    _warnTorso = _torsoDeg > _torsoMaxDeg;

    final double kneeDistX = (lk.dx - rk.dx).abs();
    final double ankleDistX = (la.dx - ra.dx).abs().clamp(1e-4, 1.0);
    final double valgusRatio = kneeDistX / ankleDistX;
    _warnValgus = valgusRatio < _valgusRatioMin;
    _warnAsym = (_emaLeftKneeDeg - _emaRightKneeDeg).abs() > _asymKneeDeg;

    bool deepByHipDrop(double romPct) => romPct >= _depthOk;
    bool deepByKneeAngle(double kneeDegL, double kneeDegR) =>
        ((kneeDegL + kneeDegR) / 2.0) <= 90.0;
    bool deepByHipBelowKnee(double hipY, double kneeY) =>
        (hipY - kneeY) >= 0.02;

    int ok = 0;
    if (deepByHipDrop(romClamped)) ok++;
    if (deepByKneeAngle(_emaLeftKneeDeg, _emaRightKneeDeg)) ok++;
    if (deepByHipBelowKnee(_emaHipY, _emaKneeY)) ok++;
    final bool isDeep = ok >= 2;

    if (!_hitBottom && (romClamped >= _bottomThreshold || isDeep)) {
      _hitBottom = true;
      _phase = 'running';
    }
    if (_hitBottom && romClamped <= _topThreshold) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRepMs >= _minRepMillis) {
        _reps++;
        _caloriesKcal = _reps * _kcalPerRep; // ★ レップごとにカロリー
        _lastRepMs = now;
      }
      _hitBottom = false;
      _phase = 'ready';
    }

    final cues = <String>[];
    if (_hitBottom && !deepByHipDrop(romClamped)) cues.add('もう少し深く');
    if (_warnValgus) cues.add('膝をつま先の向きに');
    if (_warnTorso) cues.add('胸を張る（前傾しすぎ）');
    if (_warnAsym)  cues.add('左右差に注意');

    if (!fullBody) {
      _invalidFrames++;
      if (_invalidFrames >= _dropResetFrames) {
        _resetToSearching();
      }
    } else {
      _invalidFrames = 0;
    }

    return _buildState(cues);
  }

  bool _hasRequired(List<Offset> l) {
    if (l.length <= 28) return false;
    bool ok(Offset p) => !(p.dx.isNaN || p.dy.isNaN);
    return ok(l[11]) && ok(l[12]) && ok(l[23]) && ok(l[24]) &&
           ok(l[25]) && ok(l[26]) && ok(l[27]) && ok(l[28]);
  }

  bool _isFullBodyVisible(List<Offset> l) {
    final double top = math.min(l[11].dy, l[12].dy);
    final double bottom = math.max(l[27].dy, l[28].dy);
    final double height = (bottom - top).clamp(0.0, 1.0);
    return (height >= _minBodyHeight) && (top >= _minBodyTop) && (bottom <= _maxBodyBottom);
  }

  bool _isStanding({
    required double hipY,
    required double kneeY,
    required double kneeLeftDeg,
    required double kneeRightDeg,
  }) {
    final bool hipAboveKnee = (kneeY - hipY) > _standMargin;
    final bool kneesStraight = (kneeLeftDeg > _kneeStraightDeg) && (kneeRightDeg > _kneeStraightDeg);
    return hipAboveKnee && kneesStraight;
  }

  double _kneeAngleDeg(Offset hip, Offset knee, Offset ankle) {
    final v1 = vmath.Vector2(hip.dx - knee.dx, hip.dy - knee.dy);
    final v2 = vmath.Vector2(ankle.dx - knee.dx, ankle.dy - knee.dy);
    final double dot = v1.dot(v2);
    final double len = v1.length * v2.length;
    if (len == 0) return 180;
    final double cosv = (dot / len).clamp(-1.0, 1.0);
    return vmath.degrees(math.acos(cosv));
  }

  void _resetToSearching() {
    _phase = 'searching';
    _calibrated = false;
    _standingFrames = 0;
    _fullBodyFrames = 0;
    _invalidFrames = 0;
    _hitBottom = false;

    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    _elapsedMs = 0;
    _caloriesKcal = 0.0;
  }

  SquatState _buildState(List<String> cues) => SquatState(
    reps: _reps,
    phase: _phase,
    romPct: _romPct.clamp(0.0, 1.0),
    torsoDeg: _torsoDeg,
    warnTorso: _warnTorso,
    warnValgus: _warnValgus,
    warnAsym: _warnAsym,
    cues: cues,
    calibrated: _calibrated,
    elapsedMs: _elapsedMs,
    caloriesKcal: _caloriesKcal,
  );
}
