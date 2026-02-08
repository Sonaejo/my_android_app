// lib/screens/weekly_summary_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/workout_history_store.dart';

class WeeklySummaryDetailScreen extends StatefulWidget {
  /// weekStart〜weekEnd（どちらも「含む」）を渡す
  final DateTime weekStart;
  final DateTime weekEnd;

  const WeeklySummaryDetailScreen({
    super.key,
    required this.weekStart,
    required this.weekEnd,
  });

  @override
  State<WeeklySummaryDetailScreen> createState() =>
      _WeeklySummaryDetailScreenState();
}

class _WeeklySummaryDetailScreenState
    extends State<WeeklySummaryDetailScreen> {
  late Future<_WeeklyDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WeeklyDetailData> _load() async {
    final summary = await WorkoutHistoryStore.summarizeInclusive(
      widget.weekStart,
      widget.weekEnd,
    );
    final byDay = await WorkoutHistoryStore.groupByDayInclusive(
      widget.weekStart,
      widget.weekEnd,
    );
    return _WeeklyDetailData(summary, byDay);
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.weekStart;
    final end = widget.weekEnd;

    String _fmtDate(DateTime d) => '${d.month}/${d.day}';

    return Scaffold(
      appBar: AppBar(
        title: Text('週間ワークアウト詳細 (${_fmtDate(start)}〜${_fmtDate(end)})'),
      ),
      body: FutureBuilder<_WeeklyDetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('読み込みエラー: ${snap.error}'),
            );
          }
          final data = snap.data!;
          final summary = data.summary;
          final byDay = data.byDay;

          if (summary.totalWorkouts == 0) {
            return const Center(
              child: Text('この期間のワークアウトはありません'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ───── 期間トータルサマリーカード ─────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '週間サマリー',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${summary.totalWorkouts} ワークアウト',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '合計時間: ${summary.totalSec ~/ 60}分',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '合計カロリー: ${summary.totalKcal.toStringAsFixed(1)} キロカロリー',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),
                      const Text(
                        '種目ごとの内訳',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...summary.byMode.values.map((m) {
                        final label = WorkoutHistoryStore.labelForMode(m.mode);
                        final minutes = (m.totalSec / 60).toStringAsFixed(1);
                        final kcal = m.totalKcal.toStringAsFixed(1);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '・$label: ${m.workouts}回（合計${m.totalReps}レップ / ${minutes}分 / ${kcal}kcal）',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ───── 日別の詳細 ─────
              const Text(
                '日別のワークアウト',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...byDay.entries.map((entry) {
                final date = entry.key;
                final list = entry.value;

                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      '${date.month}/${date.day} (${_weekdayLabel(date.weekday)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: list.map((e) {
                      final modeLabel =
                          WorkoutHistoryStore.labelForMode(e.mode);
                      final minutes = (e.sec / 60).toStringAsFixed(1);
                      final kcal = e.kcal.toStringAsFixed(1);

                      return ListTile(
                        title: Text(modeLabel),
                        subtitle: Text(
                          '回数: ${e.reps} / 時間: ${minutes}分 / ${kcal}kcal',
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _WeeklyDetailData {
  final WorkoutPeriodSummary summary;
  final Map<DateTime, List<WorkoutHistoryEntry>> byDay;

  _WeeklyDetailData(this.summary, this.byDay);
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    case DateTime.sunday:
      return 'Sun';
    default:
      return '';
  }
}
