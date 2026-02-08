// lib/widgets/weekly_goal_buttons.dart
import 'package:flutter/material.dart';
import '../screens/workout_history_screen.dart';

/// 週間目標の「曜日ボタン」
/// 日〜土をボタンにして、押したら履歴画面へ遷移する。
class WeeklyGoalButtons extends StatelessWidget {
  const WeeklyGoalButtons({super.key});

  @override
  Widget build(BuildContext context) {
    const labels = ['日', '月', '火', '水', '木', '金', '土'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final label = labels[index];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: OutlinedButton(
              onPressed: () {
                // 今日から見て、その週の「対象の曜日」の日付をざっくり計算する
                final now = DateTime.now();
                final todayWeekday = now.weekday % 7; // 月=1..日=7 → 0..6
                final targetWeekday = index;          // 日=0..土=6
                final diff = targetWeekday - todayWeekday;
                final targetDate = now.add(Duration(days: diff));

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WorkoutHistoryScreen(
                      initialDate: targetDate,
                    ),
                  ),
                );
              },
              child: Text(label),
            ),
          ),
        );
      }),
    );
  }
}
