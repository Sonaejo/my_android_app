// lib/screens/workout_history_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/workout_history_store.dart';
import 'weekly_summary_detail_screen.dart';

/// 1回分のワークアウト履歴（画面用のモデル）
class WorkoutLog {
  final DateTime dateTime;
  final String title;
  final String menu;
  final Duration duration;
  final double kcal;
  final String mode;

  WorkoutLog({
    required this.dateTime,
    required this.title,
    required this.menu,
    required this.duration,
    required this.kcal,
    required this.mode,
  });
}

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({
    super.key,
    required this.initialDate,
  });

  final DateTime initialDate;

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  Map<DateTime, List<WorkoutLog>> _logsByDay = <DateTime, List<WorkoutLog>>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = _normalizeDate(widget.initialDate);
    _selectedDay = _focusedDay;
    _loadLogsFromStore();
  }

  Future<void> _loadLogsFromStore() async {
    setState(() {
      _isLoading = true;
    });

    final entries = await WorkoutHistoryStore.listBetween(
      DateTime(2020, 1, 1),
      DateTime(2031, 1, 1),
    );

    final map = <DateTime, List<WorkoutLog>>{};

    for (final e in entries) {
      final label = WorkoutHistoryStore.labelForMode(e.mode);
      final title = '$label ${e.reps}回';
      final menu = label;

      final log = WorkoutLog(
        dateTime: e.dateTime,
        title: title,
        menu: menu,
        duration: Duration(seconds: e.sec.round()),
        kcal: e.kcal,
        mode: e.mode,
      );

      final key = _normalizeDate(log.dateTime);
      map.putIfAbsent(key, () => <WorkoutLog>[]).add(log);
    }

    for (final key in map.keys) {
      map[key]!.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    setState(() {
      _logsByDay = map;
      _isLoading = false;
    });
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  List<WorkoutLog> _getEventsForDay(DateTime day) {
    return _logsByDay[_normalizeDate(day)] ?? const <WorkoutLog>[];
  }

  DateTime _weekStart(DateTime base) {
    final normalized = _normalizeDate(base);
    return normalized.subtract(Duration(days: normalized.weekday % 7)); // 日曜始まり
  }

  DateTime _weekEnd(DateTime base) => _weekStart(base).add(const Duration(days: 6));

  List<WorkoutLog> _logsForCurrentWeek() {
    final base = _selectedDay ?? _focusedDay;
    final startOfWeek = _weekStart(base);
    final endOfWeek = _weekEnd(base);

    final result = <WorkoutLog>[];
    _logsByDay.forEach((date, logs) {
      if (!date.isBefore(startOfWeek) && !date.isAfter(endOfWeek)) {
        result.addAll(logs);
      }
    });

    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return result;
  }

  // ✅ 追加：保存データ（Store）をJSONにしてログへ出力する
  Future<void> dumpWorkoutHistoryToLog() async {
    final entries = await WorkoutHistoryStore.listBetween(
      DateTime(2020, 1, 1),
      DateTime(2031, 1, 1),
    );

    final list = entries.map((e) {
      return <String, dynamic>{
        'dateTime': e.dateTime.toIso8601String(),
        'mode': e.mode,
        'reps': e.reps,
        'sec': e.sec,
        'kcal': e.kcal,
      };
    }).toList();

    final jsonText = const JsonEncoder.withIndent('  ').convert(list);

    debugPrint('===== WORKOUT HISTORY DUMP START (count=${list.length}) =====');
    _logLong(jsonText);
    debugPrint('===== WORKOUT HISTORY DUMP END =====');
  }

  void _logLong(String text) {
    const chunkSize = 800;
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      debugPrint(text.substring(i, end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekLogs = _logsForCurrentWeek();

    final totalMinutes = weekLogs.fold<int>(
      0,
      (prev, e) => prev + e.duration.inMinutes,
    );
    final totalKcal = weekLogs.fold<double>(
      0,
      (prev, e) => prev + e.kcal,
    );

    final base = _selectedDay ?? _focusedDay;
    final weekStart = _weekStart(base);
    final weekEnd = _weekEnd(base);

    // 種目ごと集計（週間サマリー内の「この週に行ったトレーニング」用）
    final byMode = <String, _ModeSummary>{};
    for (final log in weekLogs) {
      final m = byMode[log.mode] ?? _ModeSummary.empty(log.mode);
      byMode[log.mode] = m.add(log);
    }
    final modeSummaries = byMode.values.toList()
      ..sort((a, b) => b.workouts.compareTo(a.workouts));

    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await dumpWorkoutHistoryToLog();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('保存データをログに出しました')),
              );
            },
            child: const Text(
              'ログ確認',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '更新',
            onPressed: _loadLogsFromStore,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  // ── カレンダー ───────────────────────────────
                  TableCalendar<WorkoutLog>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                        _selectedDay ??= _normalizeDate(focusedDay);
                      });
                    },
                    calendarStyle: const CalendarStyle(
                      markerDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent,
                      ),
                      todayDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                      selectedDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── 週間サマリー ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '週間サマリー',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WeeklySummaryDetailScreen(
                                  weekStart: weekStart,
                                  weekEnd: weekEnd,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${weekLogs.length} ワークアウト',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('合計時間: ${totalMinutes}分'),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Icon(Icons.local_fire_department),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${totalKcal.toStringAsFixed(1)} キロカロリー',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  if (weekLogs.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'この週の履歴はまだありません',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54),
                                    ),
                                  ],

                                  if (modeSummaries.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'この週に行ったトレーニング',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...modeSummaries.map((m) {
                                      final label =
                                          WorkoutHistoryStore.labelForMode(m.mode);
                                      final minutes =
                                          m.totalDuration.inMinutes.toString();
                                      final kcal =
                                          m.totalKcal.toStringAsFixed(1);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text(
                                          '・$label：${m.workouts}回  /  ${minutes}分  /  ${kcal}kcal',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── その週のワークアウト一覧 ──────────────────
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (weekLogs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'この週のワークアウトはありません',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '右下のカウンターから運動を開始すると、ここに履歴が追加されます。',
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/counter',
                                      arguments: {'mode': 'squat'},
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('カウンターを開く'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: weekLogs.length,
                      itemBuilder: (context, index) {
                        final log = weekLogs[index];
                        final date = log.dateTime;

                        final timeText =
                            '${date.month}月${date.day}日 '
                            '${date.hour.toString().padLeft(2, '0')}:'
                            '${date.minute.toString().padLeft(2, '0')}';

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.fitness_center),
                          ),
                          title: Text(log.title),
                          subtitle: Text(
                            '$timeText  /  '
                            '${log.duration.inMinutes}分  /  '
                            '${log.kcal.toStringAsFixed(1)} kcal',
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutDetailScreen(log: log),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 種目ごとの集計用（画面内専用）
class _ModeSummary {
  final String mode;
  final int workouts;
  final Duration totalDuration;
  final double totalKcal;

  const _ModeSummary({
    required this.mode,
    required this.workouts,
    required this.totalDuration,
    required this.totalKcal,
  });

  factory _ModeSummary.empty(String mode) => _ModeSummary(
        mode: mode,
        workouts: 0,
        totalDuration: Duration.zero,
        totalKcal: 0,
      );

  _ModeSummary add(WorkoutLog log) {
    return _ModeSummary(
      mode: mode,
      workouts: workouts + 1,
      totalDuration: totalDuration + log.duration,
      totalKcal: totalKcal + log.kcal,
    );
  }
}

/// 履歴から遷移する「ワークアウト詳細画面」
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.log});

  final WorkoutLog log;

  bool _isCounterMode(String mode) {
    return const {'squat', 'pushup', 'crunch', 'plank'}.contains(mode);
  }

  @override
  Widget build(BuildContext context) {
    final date = log.dateTime;
    final dateText =
        '${date.year}年${date.month}月${date.day}日 '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    final durationMinutes = log.duration.inMinutes;
    final durationSeconds = log.duration.inSeconds % 60;
    final durationText =
        '${durationMinutes}分${durationSeconds.toString().padLeft(2, '0')}秒';

    final canReplay = _isCounterMode(log.mode);

    return Scaffold(
      appBar: AppBar(
        title: Text(log.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.fitness_center),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        log.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(
                      icon: Icons.calendar_today,
                      label: '日付',
                      value: dateText,
                    ),
                    const SizedBox(height: 8),
                    _detailRow(
                      icon: Icons.list_alt,
                      label: 'メニュー',
                      value: log.menu,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '時間',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            durationText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '消費カロリー',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${log.kcal.toStringAsFixed(1)} kcal',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (canReplay) {
                    Navigator.pushNamed(
                      context,
                      '/counter',
                      arguments: {'mode': log.mode},
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('このメニューはカウンターからは再開できません')),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(canReplay ? 'このワークアウトをもう一度行う' : 'このメニューは再開できません'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
