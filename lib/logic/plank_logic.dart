// lib/logic/plank_logic.dart
import 'dart:math' as math;
import 'dart:ui' show Offset;

class PlankState {
  final double currentHoldSec;
  final double bestHoldSec;
  final double totalHoldSec;
  final bool goodForm;        // いま姿勢OKか
  final double straightScore; // 0..1 直線度
  final List<String> cues;    // フィードバック

  const PlankState({
    required this.currentHoldSec,
    required this.bestHoldSec,
    required this.totalHoldSec,
    required this.goodForm,
    required this.straightScore,
    required this.cues,
  });
}

class _Ema {
  _Ema(this.alpha);
  final double alpha;
  double? _v;
  double push(double x) {
    _v = (_v == null) ? x : (_v! * (1 - alpha) + x * alpha);
    return _v!;
  }
  double get value => _v ?? 0.0;
}

class PlankLogic {
  // ---- 調整用しきい値（必要なら自由にチューニング） ----
  static const double kAngleOkDeg = 160;   // 肩-腰-足首 角がこの値以上でほぼ一直線とみなす
  static const double kHipTiltMax = 12;    // 肩-腰の傾き（°）がこの値以下ならOK（骨盤の落ち抑制）
  static const double kHandsUnderShoulderMaxDx = 0.18; // 肩と手のx差（画面幅比）
  static const double kMinVisible = 0.5;   // 可視点率（肩/腰/足首/手/肘のうち）

  // スムージング
  final _Ema _straightEma = _Ema(0.25);
  final _Ema _tiltEma = _Ema(0.25);

  // 記録
  double _current = 0.0;
  double _best = 0.0;
  double _total = 0.0;
  bool _inGood = false;
  int _lastTsMs = DateTime.now().millisecondsSinceEpoch;

  // landmarks: Map<String, Offset> を想定（left/right Shoulder, Elbow, Wrist, Hip, Knee, Ankle）
  PlankState update(Map<String, Offset> p, {required double viewportWidth}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = math.max(0, now - _lastTsMs) / 1000.0;
    _lastTsMs = now;

    final req = [
      'leftShoulder','rightShoulder','leftHip','rightHip',
      'leftAnkle','rightAnkle','leftWrist','rightWrist',
      'leftElbow','rightElbow'
    ];
    final visible = req.where((k) => p[k] != null).length / req.length;
    if (visible < kMinVisible) {
      // 可視点不足は無条件で一時停止
      _tickTimer(dt, good: false);
      return _stateFrom(false, 0.0, const ['カメラに全身が入るように調整してね']);
    }

    // 左右平均点（肩・腰・足首・手・肘）
    Offset avg(String a, String b) => (p[a]! + p[b]!) / 2.0;
    final shoulder = avg('leftShoulder','rightShoulder');
    final hip      = avg('leftHip','rightHip');
    final ankle    = avg('leftAnkle','rightAnkle');
    final wrist    = avg('leftWrist','rightWrist');
    final elbow    = avg('leftElbow','rightElbow');

    // 肩-腰-足首 角度
    final ang = _angleDeg(shoulder, hip, ankle); // 180に近いほど一直線
    final straightScore = ((_straightEma.push(ang) - 140) / (180 - 140)).clamp(0.0, 1.0);

    // 肩-腰の傾き（水平からの角度）
    final hipTilt = ( _tiltEma.push(_lineTiltDeg(shoulder, hip)).abs() );

    // 手が肩の真下付近（ハイプランク）or 肘が肩の真下（プランク）— どちらかが許容範囲
    final dxWrist = (wrist.dx - shoulder.dx).abs() / viewportWidth;
    final dxElbow = (elbow.dx - shoulder.dx).abs() / viewportWidth;
    final supportOk = dxWrist < kHandsUnderShoulderMaxDx || dxElbow < kHandsUnderShoulderMaxDx;

    final goodForm = (ang >= kAngleOkDeg) && (hipTilt <= kHipTiltMax) && supportOk;

    // タイマー更新
    _tickTimer(dt, good: goodForm);

    // キュー
    final cues = <String>[];
    if (ang < kAngleOkDeg) cues.add('体を一直線に（お尻の上下に注意）');
    if (hipTilt > kHipTiltMax) cues.add('骨盤を水平にキープ');
    if (!supportOk) cues.add('肩の真下に手（または肘）を置く');

    return _stateFrom(goodForm, straightScore, cues);
  }

  void reset() {
    _current = 0; _best = 0; _total = 0; _inGood = false;
    _lastTsMs = DateTime.now().millisecondsSinceEpoch;
  }

  // ---- 内部ヘルパ ----------------------------------------------------------
  void _tickTimer(double dt, {required bool good}) {
    if (good) {
      _current += dt;
      _total += dt;
      _inGood = true;
      if (_current > _best) _best = _current;
    } else {
      _inGood = false;
      _current = 0.0;
    }
  }

  PlankState _stateFrom(bool good, double straightScore, List<String> cues) {
    return PlankState(
      currentHoldSec: _current,
      bestHoldSec: _best,
      totalHoldSec: _total,
      goodForm: good,
      straightScore: straightScore,
      cues: cues,
    );
  }

  static double _angleDeg(Offset a, Offset b, Offset c) {
    final v1 = Offset(a.dx - b.dx, a.dy - b.dy);
    final v2 = Offset(c.dx - b.dx, c.dy - b.dy);
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final n1 = math.sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
    final n2 = math.sqrt(v2.dx * v2.dx + v2.dy * v2.dy);
    if (n1 == 0 || n2 == 0) return 0;
    final cos = (dot / (n1 * n2)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  static double _lineTiltDeg(Offset a, Offset b) {
    final dy = b.dy - a.dy;
    final dx = b.dx - a.dx;
    if (dx.abs() < 1e-6) return 90;
    return math.atan2(dy, dx) * 180 / math.pi; // 水平0°
  }
}
