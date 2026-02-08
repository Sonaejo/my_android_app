import 'dart:math' as math;
import '../models/pose_state.dart';

class PushupFsm {
  int count = 0;
  String warning = '';
  _State _state = _State.up;
  DateTime _lastDownOk = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUpOk = DateTime.fromMillisecondsSinceEpoch(0);

  static const elbowFold = 80.0;     // これ未満でDown
  static const elbowExtend = 160.0;  // これ超でUp
  static const coreMin = 150.0;      // これ未満で腰落ち
  static const dwellMs = 150;        // 状態遷移に必要な保持時間
  static const minRepMs = 800;       // 速すぎ防止
  DateTime _lastRepAt = DateTime.fromMillisecondsSinceEpoch(0);

  void reset() {
    count = 0;
    warning = '';
    _state = _State.up;
    _lastDownOk = DateTime.fromMillisecondsSinceEpoch(0);
    _lastUpOk = DateTime.fromMillisecondsSinceEpoch(0);
    _lastRepAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void update(PoseState p) {
    warning = '';
    final elbowMin = math.min(p.elbowLeft, p.elbowRight);
    final now = DateTime.now();

    if (p.coreAngle < coreMin) {
      warning = '腰が落ちています';
    }

    switch (_state) {
      case _State.up:
        if (elbowMin < elbowFold && p.coreAngle >= coreMin) {
          if (now.difference(_lastDownOk).inMilliseconds > dwellMs) {
            _lastDownOk = now;
            _state = _State.down;
          }
        } else {
          _lastDownOk = now;
        }
        break;
      case _State.down:
        if (elbowMin > elbowExtend) {
          if (now.difference(_lastUpOk).inMilliseconds > dwellMs) {
            _lastUpOk = now;
            if (now.difference(_lastRepAt).inMilliseconds >= minRepMs) {
              count++;
              _lastRepAt = now;
            }
            _state = _State.up;
          }
        } else {
          _lastUpOk = now;
        }
        break;
    }
  }
}

enum _State { up, down }
