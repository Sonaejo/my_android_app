// lib/widgets/skeleton_painter.dart
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class SkeletonPainter extends CustomPainter {
  final List<Offset> lms01; // 0..1 正規化
  final bool mirrorX;
  SkeletonPainter(this.lms01, {this.mirrorX = false});

  static const pairs = [
    [11,12],[11,13],[13,15],[12,14],[14,16],
    [11,23],[12,24],[23,24],[23,25],[25,27],[24,26],[26,28],
    [11,7],[12,8],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (lms01.isEmpty) return;

    bool valid(int i) =>
        i >= 0 && i < lms01.length && !(lms01[i].dx.isNaN || lms01[i].dy.isNaN);

    if (mirrorX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final line = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.lightBlueAccent;

    Offset tr(int i) => Offset(lms01[i].dx * size.width, lms01[i].dy * size.height);

    for (final p in pairs) {
      final a = p[0], b = p[1];
      if (valid(a) && valid(b)) {
        canvas.drawLine(tr(a), tr(b), line);
      }
    }

    final dot = Paint()..color = Colors.white;
    for (int i = 0; i < lms01.length; i++) {
      if (valid(i)) canvas.drawCircle(tr(i), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter old) =>
      old.mirrorX != mirrorX || !const ListEquality<Offset>().equals(old.lms01, lms01);
}
