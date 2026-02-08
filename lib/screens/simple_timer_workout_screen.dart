// lib/screens/simple_timer_workout_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// シンプルな時間制ワークアウト画面。
/// 例: 腹筋 30秒 → 休憩10秒 → 30秒 → 休憩10秒 → 30秒 (3セット)
///
/// Navigator.pushNamed(
///   context,
///   '/simple_timer',
///   arguments: {
///     'title': '上体起こし(腹筋)',
///     'workSeconds': 30,
///     'restSeconds': 10,
///     'sets': 3,
///   },
/// );
class SimpleTimerWorkoutScreen extends StatefulWidget {
  const SimpleTimerWorkoutScreen({super.key});

  @override
  State<SimpleTimerWorkoutScreen> createState() =>
      _SimpleTimerWorkoutScreenState();
}

class _SimpleTimerWorkoutScreenState extends State<SimpleTimerWorkoutScreen> {
  // 用意カウント
  static const int _readySecondsDefault = 5;

  late final String _title;
  late final int _workSeconds;
  late final int _restSeconds;
  late final int _sets;
  late final int _readySeconds;

  Timer? _timer;
  bool _started = false;
  bool _finished = false;

  /// -1: 用意中
  ///  0〜: segments の index
  int _phaseIndex = -1;
  int _remaining = 0;

  List<_Segment> get _segments {
    // work / rest を交互に並べる
    final List<_Segment> list = [];
    for (int s = 0; s < _sets; s++) {
      final setNum = s + 1;
      list.add(
        _Segment(
          label: '$_title\n$setNumセット目',
          seconds: _workSeconds,
          isRest: false,
          setIndex: s,
        ),
      );
      if (s != _sets - 1 && _restSeconds > 0) {
        list.add(
          _Segment(
            label: '休憩',
            seconds: _restSeconds,
            isRest: true,
            setIndex: s,
          ),
        );
      }
    }
    return list;
  }

  _Segment? get _currentSegment {
    if (_phaseIndex < 0 || _phaseIndex >= _segments.length) return null;
    return _segments[_phaseIndex];
  }

  @override
  void initState() {
    super.initState();
    // ルート引数の取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
              {};
      _title = (args['title'] as String?) ?? 'ワークアウト';
      _workSeconds = (args['workSeconds'] as int?) ?? 30;
      _restSeconds = (args['restSeconds'] as int?) ?? 10;
      _sets = (args['sets'] as int?) ?? 3;
      _readySeconds =
          (args['readySeconds'] as int?) ?? _readySecondsDefault;

      _resetState();
      setState(() {}); // 画面更新
    });
  }

  void _resetState() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _finished = false;
    _phaseIndex = -1; // 用意
    _remaining = _readySeconds;
  }

  void _start() {
    if (_started && !_finished) return; // 実行中なら何もしない

    setState(() {
      _started = true;
      _finished = false;
      _phaseIndex = -1;
      _remaining = _readySeconds;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;

    setState(() {
      if (_remaining > 0) {
        _remaining -= 1;
        return;
      }

      // 今のフェーズを進める
      if (_phaseIndex == -1) {
        // 用意 → 最初のワーク
        _phaseIndex = 0;
        _remaining = _segments[0].seconds;
        return;
      }

      // 次のセグメントへ
      if (_phaseIndex < _segments.length - 1) {
        _phaseIndex += 1;
        _remaining = _segments[_phaseIndex].seconds;
        return;
      }

      // 全部終了
      _finished = true;
      _timer?.cancel();
      _timer = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _mainLabel {
    if (!_started) {
      return '準備OK？';
    }
    if (_finished) {
      return 'おつかれさま！';
    }
    if (_phaseIndex == -1) {
      return '用意スタート';
    }
    final seg = _currentSegment;
    if (seg == null) return '';
    if (seg.isRest) return '休憩';
    return seg.label.split('\n').first; // 種目名だけ
  }

  String get _subLabel {
    if (!_started) {
      return 'スタートを押すと\n$_title ${_workSeconds}秒 x $_setsセット';
    }
    if (_finished) {
      return '$_title ${_sets}セット 完了';
    }
    if (_phaseIndex == -1) {
      return '用意 ${_readySeconds}秒';
    }
    final seg = _currentSegment;
    if (seg == null) return '';
    if (seg.isRest) {
      return '次のセットまで休憩';
    } else {
      return 'エクササイズ ${seg.setIndex + 1}/$_sets';
    }
  }

  String get _bigNumber {
    if (_finished) return '0';
    return _remaining.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.black.withOpacity(0.85);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // 背景にうっすら種目名だけ出してもOK
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Center(
                  child: Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // メインコンテンツ
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 上部バー
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (_started && !_finished && _phaseIndex >= 0)
                        Text(
                          'セット ${_currentSegment?.setIndex != null ? _currentSegment!.setIndex + 1 : 1}/$_sets',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 中央のラベル + カウント
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _mainLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _bigNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 120,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _subLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // 下部のボタン
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        if (_finished) {
                          // もう一度やる
                          _resetState();
                          _start();
                        } else if (!_started) {
                          _start();
                        }
                      },
                      child: Text(
                        _finished
                            ? 'もう一度'
                            : _started
                                ? '進行中…'
                                : 'スタート！',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ワーク or 休憩の1区間を表す
class _Segment {
  final String label;
  final int seconds;
  final bool isRest;
  final int setIndex; // 0-based

  const _Segment({
    required this.label,
    required this.seconds,
    required this.isRest,
    required this.setIndex,
  });
}
