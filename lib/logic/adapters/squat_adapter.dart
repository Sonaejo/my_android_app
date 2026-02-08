import 'package:flutter/material.dart';
import '../pose_logic.dart';
import '../squat_logic.dart';

/// SquatLogic → PoseLogic 変換アダプタ
class SquatAdapter implements PoseLogic {
  SquatLogic _inner; // ← finalを外す

  SquatAdapter(SquatLogic inner) : _inner = inner;

  @override
  String get id => 'squat';

  @override
  void reset() {
    // 再生成で内部状態とタイマーをリセット
    _inner = SquatLogic();
  }

  @override
  PoseState process(PoseFrame frame) {
    final s = _inner.process(frame.lm01); // SquatState

    return PoseState(
      reps: s.reps,
      progress: s.romPct.clamp(0.0, 1.0),         // 進捗＝ROM(0..1)
      phase: _mapPhase(s.phase),                  // string → enum
      calibrated: s.calibrated,
      warns: {
        'torso': s.warnTorso,
        'valgus': s.warnValgus,
        'asym': s.warnAsym,
      },
      cues: s.cues,
      metrics: {
        'torsoDeg': s.torsoDeg,                   // 体幹角（deg）
        'elapsedSec': s.elapsedMs / 1000.0,       // ★ HUD用タイマー
        'kcal': s.caloriesKcal,                   // ★ HUD用カロリー
      },
      extras: const {},
    );
  }

  PosePhase _mapPhase(String phase) {
    switch (phase) {
      case 'searching':
        return PosePhase.searching;
      case 'calibrating':
        return PosePhase.calibrating;
      case 'ready':
        return PosePhase.ready;
      case 'running':
        return PosePhase.running;
      default:
        return PosePhase.running;
    }
  }
}
