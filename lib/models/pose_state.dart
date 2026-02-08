import 'dart:math' as math;
import 'dart:ui' show Offset;

class PoseState {
  static const keys = [
    'leftShoulder',
    'rightShoulder',
    'leftElbow',
    'rightElbow',
    'leftWrist',
    'rightWrist',
    'leftHip',
    'rightHip',
    'leftKnee',
    'rightKnee',
    'leftAnkle',
    'rightAnkle',
  ];

  final Map<String, Offset> namedPoints = {};
  final _Smooth _smoothElbowL = _Smooth(5);
  final _Smooth _smoothElbowR = _Smooth(5);
  final _Smooth _smoothCore = _Smooth(5);

  double elbowLeft = 180, elbowRight = 180, coreAngle = 180;

  void updateFromMap(Map<String, dynamic> m) {
    for (final k in keys) {
      final v = m[k];
      if (v is Map) {
        final x = (v['x'] ?? 0.0) as num;
        final y = (v['y'] ?? 0.0) as num;
        namedPoints[k] = Offset(x.toDouble(), y.toDouble());
      }
    }

    final ls = namedPoints['leftShoulder'];
    final le = namedPoints['leftElbow'];
    final lw = namedPoints['leftWrist'];
    final rs = namedPoints['rightShoulder'];
    final re = namedPoints['rightElbow'];
    final rw = namedPoints['rightWrist'];
    final lh = namedPoints['leftHip'];
    final rh = namedPoints['rightHip'];
    final lk = namedPoints['leftKnee'];
    final rk = namedPoints['rightKnee'];

    if (ls != null && le != null && lw != null) {
      elbowLeft = _smoothElbowL.add(_angle(ls, le, lw));
    }
    if (rs != null && re != null && rw != null) {
      elbowRight = _smoothElbowR.add(_angle(rs, re, rw));
    }
    if (ls != null && rs != null && lh != null && rh != null && lk != null && rk != null) {
      final shoulder = (ls + rs) / 2.0;
      final hip = (lh + rh) / 2.0;
      final knee = (lk + rk) / 2.0;
      coreAngle = _smoothCore.add(_angle(shoulder, hip, knee));
    }
  }

  double _angle(Offset a, Offset b, Offset c) {
    final ab = a - b;
    final cb = c - b;
    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final na = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final nc = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
    final cosv = (dot / (na * nc)).clamp(-1.0, 1.0);
    return math.acos(cosv) * 180 / math.pi;
  }
}

class _Smooth {
  final int n;
  final List<double> _buf = [];
  _Smooth(this.n);
  double add(double v) {
    _buf.add(v);
    if (_buf.length > n) _buf.removeAt(0);
    return _buf.reduce((a, b) => a + b) / _buf.length;
  }
}
