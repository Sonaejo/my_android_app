// lib/screens/weekly_goal_screen.dart
import 'package:flutter/material.dart';
import '../services/weekly_goal_store.dart';
import '../screens/home_screen.dart';

class WeeklyGoalScreen extends StatefulWidget {
  const WeeklyGoalScreen({super.key});

  @override
  State<WeeklyGoalScreen> createState() => _WeeklyGoalScreenState();
}

class _WeeklyGoalScreenState extends State<WeeklyGoalScreen> {
  late int _target; // 1..7

  @override
  void initState() {
    super.initState();
    _target = WeeklyGoalStore.targetDays.value;
  }

  @override
  Widget build(BuildContext context) {
    final week = WeeklyGoalStore.currentWeekDays();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          '週の目標を設定',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          const SizedBox(height: 8),
          const Text(
            'より良い結果を出すには、週に3日以上の\nトレーニングを推奨しています。',
            style: TextStyle(color: Colors.black54, height: 1.4, fontSize: 16),
          ),
          const SizedBox(height: 24),

          // ── 回数セグメント（1..7）
          Row(
            children: const [
              Icon(Icons.track_changes, color: Colors.black87),
              SizedBox(width: 8),
              Text('毎週のトレーニング日数',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(7, (i) {
              final v = i + 1;
              final selected = v == _target;
              return ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    '$v',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _target = v),
                selectedColor: HomeScreen.accentBlue,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: const Color(0xFFF2F3F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: selected ? Colors.transparent : Colors.black26),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }),
          ),

          const SizedBox(height: 28),

          // ── 今週のプレビュー（達成済みは色付き）
          Row(
            children: const [
              Icon(Icons.calendar_today, color: Colors.black87),
              SizedBox(width: 8),
              Text('今週のプレビュー',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  color: Color(0x14000000),
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: week.map((d) {
                final isDone = WeeklyGoalStore.isDone(d);
                final isToday = _isSameDay(d, DateTime.now());
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${d.day}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDone
                            ? HomeScreen.accentBlue
                            : (isToday ? const Color(0xFFE8F0FF) : Colors.transparent),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isDone
                              ? HomeScreen.accentBlue
                              : (isToday ? HomeScreen.accentBlue : Colors.black26),
                        ),
                      ),
                      child: Text(
                        WeeklyGoalStore.labelFromWeekday(d.weekday),
                        style: TextStyle(
                          color: isDone ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 40),

          // ── 保存ボタン（大）
          SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HomeScreen.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await WeeklyGoalStore.setTargetDays(_target);
                if (mounted) Navigator.pop(context, true);
              },
              child:
                  const Text('保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
