import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

import '../fsm/pushup_fsm.dart';
import '../models/pose_state.dart';

class HUD extends StatelessWidget {
  const HUD({
    super.key,
    required this.fsm,
    required this.pose,
    required this.running,
    required this.info,
  });
  final PushupFsm fsm;
  final PoseState pose;
  final bool running;
  final String info;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('REPS', fsm.count.toString()),
      _chip('ELBOW L/R',
          '${pose.elbowLeft.toStringAsFixed(0)}° / ${pose.elbowRight.toStringAsFixed(0)}°'),
      _chip('CORE', '${pose.coreAngle.toStringAsFixed(0)}°'),
    ];
    if (fsm.warning.isNotEmpty) chips.add(_chip('WARN', fsm.warning));
    if (!running && info.isNotEmpty) chips.add(_chip('INFO', info));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in chips) ...[w, const SizedBox(height: 8)],
      ],
    );
  }

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(value),
            ],
          ),
        ),
      );
}
