// lib/logic/adapters/crunch_adapter.dart
import 'package:flutter/material.dart';
import '../pose_logic.dart';
import '../crunch_logic.dart';

/// CrunchLogic → PoseLogic 変換アダプタ
class CrunchAdapter implements PoseLogic {
  final CrunchLogic _inner;

  CrunchAdapter(this._inner);

  @override
  String get id => 'crunch';

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
      },
      cues: s.cues,
      metrics: {
        // ★ 体幹角度（Crunch用）
        'coreDeg': s.coreDeg,

        // ★ 時間（秒）… PoseCounterScreen 側の elapsedSec 参照用
        'elapsedSec': s.elapsedMs / 1000.0,

        // ★ カロリー … PoseCounterScreen 側の kcal 参照用
        'kcal': s.caloriesKcal,
      },
      extras: const {},
    );
  }
}
