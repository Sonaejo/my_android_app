// lib/screens/rest_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

class RestScreen extends StatefulWidget {
  const RestScreen({super.key, this.seconds = 30});
  final int seconds;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> with WidgetsBindingObserver {
  late int _total; // 休憩の合計秒
  late int _left;  // 残り秒
  Timer? _timer;
  bool _running = true; // 画面表示と同時に開始

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _total = widget.seconds.clamp(1, 3600);
    _left = _total;
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // アプリのライフサイクルに応じて自動一時停止
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _pause();
    }
  }

  // ----- タイマー操作 -----
  void _tick(Timer _) {
    setState(() {
      _left = (_left - 1).clamp(0, 9999);
    });
    if (_left == 0) {
      _timer?.cancel();
      if (mounted) Navigator.pop(context); // 終了したら戻る
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    setState(() => _running = true);
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _toggle() => _running ? _pause() : _start();

  void _reset() {
    _timer?.cancel();
    setState(() {
      _left = _total;
      _running = false;
    });
  }

  void _addSeconds(int delta) {
    // 総時間・残り時間ともに調整（直感的に「延長/短縮」）
    final newTotal = (_total + delta).clamp(1, 3600);
    final used = _total - _left;
    final newLeft = (newTotal - used).clamp(0, 3600);

    setState(() {
      _total = newTotal;
      _left = newLeft;
    });

    // 0 になったら終了挙動に合わせる
    if (_left == 0) {
      _timer?.cancel();
      if (mounted) Navigator.pop(context);
    }
  }

  // ----- 表示用 -----
  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = r.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  double get _progress {
    // CircularProgressIndicator は 0.0..1.0
    if (_total <= 0) return 0;
    return (1 - (_left / _total)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('休憩')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 円形プログレス + 残り時間
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 10,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        _fmt(_left),
                        key: ValueKey(_left),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '残り',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // 時間調整ボタン
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _secButton(label: '-10秒', onTap: () => _addSeconds(-10)),
                  _secButton(label: '-5秒', onTap: () => _addSeconds(-5)),
                  _secButton(label: '+5秒', onTap: () => _addSeconds(5)),
                  _secButton(label: '+10秒', onTap: () => _addSeconds(10)),
                ],
              ),

              const SizedBox(height: 28),

              // コントロール
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    label: Text(_running ? '一時停止' : '再開'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay),
                    label: const Text('リセット'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 戻る／スキップ
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('スキップして戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 小さな時間調整ボタン
  Widget _secButton({required String label, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
