import 'dart:async';
import 'package:flutter/material.dart';

import '../services/workout_history_store.dart'; // ✅ 追加：履歴保存

/// ✅ 初心者ルーチン：一覧 → 次へ → 種目(GIF) → 休憩30秒 → 種目(GIF) … → 結果画面
class BeginnerRoutinePreviewScreen extends StatelessWidget {
  const BeginnerRoutinePreviewScreen({super.key});

  BeginnerRoutine buildRoutine() {
    return const BeginnerRoutine(
      id: 'beginner_fullbody_10min',
      title: '全身ベーシック（10分）',
      subtitle: 'フォーム重視。無理せず「あと2回できる」くらいでOK。',
      rounds: 1, // 互換のため残しているだけ（今回は1周固定）
      restBetweenRoundsSec: 30, // ✅ 種目間休憩 = 30秒
      items: [
        RoutineItem.exercise(
          name: 'スクワット',
          type: RoutineType.reps,
          targetReps: 30,
          asset: 'assets/gifs/squat.gif',
        ),
        RoutineItem.exercise(
          name: 'プッシュアップ（簡単）',
          type: RoutineType.reps,
          targetReps: 20,
          asset: 'assets/gifs/knee_pushup.gif',
        ),
        RoutineItem.exercise(
          name: 'クランチ(上体起こし)',
          type: RoutineType.reps,
          targetReps: 20,
          asset: 'assets/gifs/situp.gif',
        ),
        RoutineItem.exercise(
          name: 'プランク',
          type: RoutineType.time,
          targetSec: 30,
          asset: 'assets/gifs/plank.png',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final routine = buildRoutine();
    final steps = routine.expandToSteps();

    return Scaffold(
      appBar: AppBar(title: const Text('初心者向けメニュー')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _TopCard(routine: routine, totalSteps: steps.length),
          const SizedBox(height: 12),
          const Text(
            '今日のメニュー',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ..._buildPreviewList(routine),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BeginnerRoutineRunnerScreen(routine: routine),
                  ),
                );
              },
              child: const Text('次へ'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ✅ 1つ前（ホーム）へ戻る想定
              },
              child: const Text('ホームに戻る'),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 一覧は「種目だけ」にする（休憩はRunner側でのみ表示）
  List<Widget> _buildPreviewList(BeginnerRoutine routine) {
    return routine.items.map((it) => _PreviewTile(item: it)).toList();
  }
}

class BeginnerRoutineRunnerScreen extends StatefulWidget {
  const BeginnerRoutineRunnerScreen({
    super.key,
    required this.routine,
  });

  final BeginnerRoutine routine;

  @override
  State<BeginnerRoutineRunnerScreen> createState() =>
      _BeginnerRoutineRunnerScreenState();
}

class _BeginnerRoutineRunnerScreenState extends State<BeginnerRoutineRunnerScreen> {
  late final List<RoutineStep> _steps;
  int _index = 0;

  Timer? _timer;
  int _timeLeft = 0; // 休憩 or 時間種目の残り秒

  final Stopwatch _stopwatch = Stopwatch(); // ✅ 実測時間（休憩含む）

  @override
  void initState() {
    super.initState();
    _steps = widget.routine.expandToSteps();
    _stopwatch.start();
    _enterStep(); // 最初のステップ開始
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  RoutineStep get _current => _steps[_index];

  /// ✅ 休憩中に「次の種目」を表示するために取得
  RoutineItem? _nextExerciseAfterRest() {
    for (int i = _index + 1; i < _steps.length; i++) {
      final s = _steps[i];
      if (s.kind == StepKind.exercise) return s.exercise;
    }
    return null;
  }

  void _enterStep() {
    _timer?.cancel();
    final step = _current;

    // ── 休憩タイマー ─────────────────────────────
    if (step.kind == StepKind.rest) {
      _timeLeft = step.restSec ?? 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_timeLeft <= 1) {
          t.cancel();
          setState(() => _timeLeft = 0);
          _next(); // 休憩終了→自動で次へ
        } else {
          setState(() => _timeLeft--);
        }
      });
      return;
    }

    // ── 時間種目タイマー（例：プランク） ───────────
    final ex = step.exercise!;
    if (ex.type == RoutineType.time) {
      _timeLeft = ex.targetSec ?? 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_timeLeft <= 1) {
          t.cancel();
          setState(() => _timeLeft = 0);
          _next(); // 種目終了→自動で次へ
        } else {
          setState(() => _timeLeft--);
        }
      });
    } else {
      // reps種目は手動完了なのでタイマーなし
      _timeLeft = 0;
    }
  }

  void _finish() {
    _timer?.cancel();
    _stopwatch.stop();

    final elapsedSec = _stopwatch.elapsed.inSeconds;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BeginnerRoutineResultScreen(
          routine: widget.routine,
          elapsedSec: elapsedSec,
        ),
      ),
    );
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      _finish(); // ✅ 完了→結果画面へ
      return;
    }
    setState(() => _index++);
    _enterStep();
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() => _index--);
    _enterStep();
  }

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final stepNo = _index + 1;

    return Scaffold(
      appBar: AppBar(title: Text(widget.routine.title)),
      body: SafeArea(
        child: Column(
          children: [
            // 上：進捗
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '次へ $stepNo/$total',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _prev, icon: const Icon(Icons.chevron_left)),
                  IconButton(onPressed: _next, icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),

            Expanded(
              child: _current.kind == StepKind.rest
                  ? _RestView(
                      leftSec: _timeLeft,
                      nextItem: _nextExerciseAfterRest(),
                      onPlus20: () => setState(() => _timeLeft += 20),
                      onSkip: _next,
                    )
                  : _ExerciseGifView(
                      step: _current,
                      timeLeft: _timeLeft,
                      onDone: _next,
                    ),
            ),

            if (_current.kind == StepKind.exercise)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    _timer?.cancel(); // ✅ 時間種目のタイマーを止める
                    _next();
                  },
                  child: Builder(
                    builder: (_) {
                      final isLast = _index == total - 1;
                      final isPlank =
                          _current.kind == StepKind.exercise && _current.exercise?.name == 'プランク';
                      return Text(
                        isLast ? (isPlank ? '結果表示へ' : '完了') : '完了して次へ',
                      );
                    },
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ============================================================================
// モデル
// ============================================================================

enum RoutineType { reps, time }

class BeginnerRoutine {
  final String id;
  final String title;
  final String subtitle;

  /// ※ 今回は 1周固定（互換のために残してあるだけ）
  final int rounds;

  /// ✅ 今回は「種目間休憩（固定）」として使う
  final int restBetweenRoundsSec;

  final List<RoutineItem> items;

  const BeginnerRoutine({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.rounds,
    required this.restBetweenRoundsSec,
    required this.items,
  });

  /// ✅ 種目→休憩→種目→休憩…（最後は休憩なし）
  List<RoutineStep> expandToSteps() {
    final steps = <RoutineStep>[];
    final round = 1;

    for (int i = 0; i < items.length; i++) {
      steps.add(RoutineStep.exercise(items[i], round: round));

      final isLast = i == items.length - 1;
      if (!isLast) {
        steps.add(RoutineStep.rest(restBetweenRoundsSec, round: round));
      }
    }
    return steps;
  }
}

class RoutineItem {
  final String name;
  final RoutineType type;
  final int? targetReps;
  final int? targetSec;
  final String asset; // ✅ GIF/PNGのアセットパス

  const RoutineItem._({
    required this.name,
    required this.type,
    this.targetReps,
    this.targetSec,
    required this.asset,
  });

  const RoutineItem.exercise({
    required String name,
    required RoutineType type,
    int? targetReps,
    int? targetSec,
    required String asset,
  }) : this._(
          name: name,
          type: type,
          targetReps: targetReps,
          targetSec: targetSec,
          asset: asset,
        );
}

enum StepKind { exercise, rest }

class RoutineStep {
  final StepKind kind;
  final RoutineItem? exercise;
  final int? restSec;
  final int round;

  const RoutineStep._(
    this.kind, {
    this.exercise,
    this.restSec,
    required this.round,
  });

  factory RoutineStep.exercise(RoutineItem item, {required int round}) =>
      RoutineStep._(StepKind.exercise, exercise: item, round: round);

  factory RoutineStep.rest(int sec, {required int round}) =>
      RoutineStep._(StepKind.rest, restSec: sec, round: round);
}

// ============================================================================
// UI
// ============================================================================

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.routine,
    required this.totalSteps,
  });

  final BeginnerRoutine routine;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(routine.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(routine.subtitle, style: const TextStyle(color: Colors.black54, height: 1.3)),
          const SizedBox(height: 10),
          Row(
            children: [
              const _Badge(label: '約10分'),
              const SizedBox(width: 8),
              _Badge(label: '${routine.items.length}種目'),
              const SizedBox(width: 8),
              _Badge(label: '休憩 ${routine.restBetweenRoundsSec}s'),
              const SizedBox(width: 8),
              _Badge(label: 'ステップ $totalSteps'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E3E7)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.item});
  final RoutineItem item;

  @override
  Widget build(BuildContext context) {
    final sub = item.type == RoutineType.reps ? '×${item.targetReps ?? 0}' : '${item.targetSec ?? 0}s';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE0E3E7)),
      ),
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }
}

/// ✅ 種目表示（GIF/PNG）
class _ExerciseGifView extends StatelessWidget {
  const _ExerciseGifView({
    required this.step,
    required this.timeLeft,
    required this.onDone,
  });

  final RoutineStep step;
  final int timeLeft;
  final VoidCallback onDone;

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final item = step.exercise!;
    final isTime = item.type == RoutineType.time;

    Widget media() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.white,
          child: Image.asset(
            item.asset,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('画像が見つかりません（assets設定を確認）'),
            ),
          ),
        ),
      );
    }

    Widget info() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('セット ${step.round}', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            isTime ? '時間：${item.targetSec ?? 0}秒' : '回数：×${item.targetReps ?? 0}',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isTime ? _mmss(timeLeft) : '×${item.targetReps ?? 0}',
                style: TextStyle(fontSize: isTime ? 54 : 44, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (isTime)
            const Center(
              child: Text('時間種目は自動で次へ進みます', style: TextStyle(color: Colors.black54)),
            ),
          const SizedBox(height: 6),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bool isWide = w >= 720;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E3E7)),
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 260,
                        child: AspectRatio(
                          aspectRatio: 1 / 1,
                          child: media(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: info(),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / 1,
                        child: media(),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: info(),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _RestView extends StatelessWidget {
  const _RestView({
    required this.leftSec,
    required this.nextItem,
    required this.onPlus20,
    required this.onSkip,
  });

  final int leftSec;
  final RoutineItem? nextItem;
  final VoidCallback onPlus20;
  final VoidCallback onSkip;

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2962FF),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '休憩',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    if (nextItem != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  color: Colors.white,
                                  child: Image.asset(
                                    nextItem!.asset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Text('画像なし', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '次のメニュー',
                                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nextItem!.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nextItem!.type == RoutineType.time
                                        ? '${nextItem!.targetSec ?? 0}秒'
                                        : '×${nextItem!.targetReps ?? 0}',
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _mmss(leftSec),
                          style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.22),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onPlus20,
                        child: const Text('+20s', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2962FF),
                        ),
                        onPressed: onSkip,
                        child: const Text('スキップ', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ✅ 結果画面（最後に表示）
// - 合計時間
// - 消費カロリー（30kcal固定）
// - 種目数
// ✅ 追加：結果画面に入ったら履歴へ保存（1回だけ）
// ============================================================================

class BeginnerRoutineResultScreen extends StatefulWidget {
  const BeginnerRoutineResultScreen({
    super.key,
    required this.routine,
    required this.elapsedSec,
  });

  final BeginnerRoutine routine;
  final int elapsedSec;

  @override
  State<BeginnerRoutineResultScreen> createState() => _BeginnerRoutineResultScreenState();
}

class _BeginnerRoutineResultScreenState extends State<BeginnerRoutineResultScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveHistoryOnce();
  }

  Future<void> _saveHistoryOnce() async {
    if (_saved) return;
    _saved = true;

    const fixedKcal = 30.0;

    // ✅ 初心者メニューを「1回」として保存（reps=1）
    await WorkoutHistoryStore.addWorkout(
      mode: widget.routine.id, // 'beginner_fullbody_10min'
      reps: 1,
      sec: widget.elapsedSec.toDouble(),
      kcal: fixedKcal,
      skipIfZeroReps: false,
    );
  }

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const fixedKcal = 30; // 表示
    final count = widget.routine.items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('結果')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0E3E7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('お疲れ様でした！', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(widget.routine.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _ResultRow(label: '合計時間', value: _mmss(widget.elapsedSec)),
                  const SizedBox(height: 8),
                  _ResultRow(label: '消費カロリー（目安）', value: '$fixedKcal kcal'),
                  const SizedBox(height: 8),
                  _ResultRow(label: '種目数', value: '$count'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BeginnerRoutineRunnerScreen(routine: widget.routine),
                    ),
                  );
                },
                child: const Text('もう一度やる'),
              ),
            ),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('ホームに戻る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}
