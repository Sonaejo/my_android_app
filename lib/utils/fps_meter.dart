import 'dart:collection';

/// 直近1秒の“処理できたフレーム数”から実効FPSを計算
class FpsMeter {
  final int windowMs;
  final Queue<int> _times = Queue<int>();
  double _fps = 0.0;

  FpsMeter({this.windowMs = 1000});

  /// フレーム処理が終わったタイミングで呼ぶ
  void tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _times.addLast(now);
    while (_times.isNotEmpty && now - _times.first > windowMs) {
      _times.removeFirst();
    }
    if (_times.length >= 2) {
      final dt = (_times.last - _times.first).clamp(1, 1 << 31);
      _fps = (_times.length - 1) * 1000.0 / dt;
    }
  }

  double get value => _fps;
  String get label => '${_fps.toStringAsFixed(1)} FPS';
}
