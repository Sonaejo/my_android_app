import 'package:flutter/material.dart';
import '../pose_logic.dart';
import '../pushup_logic.dart';

/// PushupLogic → PoseLogic 変換アダプタ
class PushupAdapter implements PoseLogic {
  final PushupLogic _inner;

  PushupAdapter(this._inner);

  @override
  String get id => 'pushup';

  @override
  void reset() => _inner.reset();

  @override
  PoseState process(PoseFrame frame) {
    final s = _inner.process(frame.lm01);

    return PoseState(
      reps: s.reps,
      progress: s.depthPct.clamp(0.0, 1.0),
      phase: PosePhase.running,
      calibrated: true,
      warns: {
        'sag': s.warnSag,
        'asym': s.warnAsym,
        'range': s.warnRange,
      },
      cues: s.cues,
      metrics: {
        'bodySagDeg': s.bodySagDeg,
        'elapsedSec': s.elapsedMs / 1000.0, // ★ HUD用
        'kcal': s.caloriesKcal,             // ★ HUD用
      },
      extras: const {},
    );
  }
}
