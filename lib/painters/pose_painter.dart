import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  PosePainter(this.points, {this.strokeWidth = 4, this.mirror = false});
  final Map<String, Offset> points;
  final double strokeWidth;
  final bool mirror;

  @override
  void paint(Canvas c, Size size) {
    if (points.isEmpty) return;

    Offset? p(String k) {
      final pt = points[k];
      if (pt == null) return null;
      final x = mirror ? (1.0 - pt.dx) : pt.dx; // フロントなら左右反転
      return Offset(x * size.width, pt.dy * size.height);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.greenAccent;

    void link(String a, String b) {
      final pa = p(a), pb = p(b);
      if (pa != null && pb != null) c.drawLine(pa, pb, paint);
    }

    // 胴
    link('leftShoulder', 'rightShoulder');
    link('leftHip', 'rightHip');
    link('leftShoulder', 'leftHip');
    link('rightShoulder', 'rightHip');

    // 腕
    link('leftShoulder', 'leftElbow');
    link('leftElbow', 'leftWrist');
    link('rightShoulder', 'rightElbow');
    link('rightElbow', 'rightWrist');

    // 脚
    link('leftHip', 'leftKnee');
    link('leftKnee', 'leftAnkle');
    link('rightHip', 'rightKnee');
    link('rightKnee', 'rightAnkle');
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.mirror != mirror ||
      oldDelegate.strokeWidth != strokeWidth;
}
