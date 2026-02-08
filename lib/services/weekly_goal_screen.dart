import 'package:flutter/material.dart';
import '../services/weekly_goal_store.dart';

class WeeklyGoalScreen extends StatefulWidget {
  const WeeklyGoalScreen({super.key});

  @override
  State<WeeklyGoalScreen> createState() => _WeeklyGoalScreenState();
}

class _WeeklyGoalScreenState extends State<WeeklyGoalScreen> {
  // ★ 名前を store に合わせる
  int _target = WeeklyGoalStore.targetDays.value;
  int _weekStart = WeeklyGoalStore.weekStart.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('週の目標を設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          const SizedBox(height: 8),
          const Text(
            'より良い結果を出すには、週に3日以上のトレーニングを推奨しています。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Icon(Icons.gps_fixed, size: 18, color: Colors.redAccent),
              SizedBox(width: 6),
              Text('毎週のトレーニング日数',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(7, (i) {
              final n = i + 1;
              final selected = _target == n;
              return ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  child: Text('$n'),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _target = n),
                selectedColor: const Color(0xFF2962FF), // ※将来M3ならcolor: WidgetStateProperty... に
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: const Color(0xFFF7F8FA),
                side: const BorderSide(color: Color(0xFFE0E3E7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.event_note, size: 18, color: Colors.redAccent),
              SizedBox(width: 6),
              Text('週の1日目', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _weekStart,
            items: const [
              DropdownMenuItem(value: 1, child: Text('月曜日')),
              DropdownMenuItem(value: 2, child: Text('火曜日')),
              DropdownMenuItem(value: 3, child: Text('水曜日')),
              DropdownMenuItem(value: 4, child: Text('木曜日')),
              DropdownMenuItem(value: 5, child: Text('金曜日')),
              DropdownMenuItem(value: 6, child: Text('土曜日')),
              DropdownMenuItem(value: 7, child: Text('日曜日')),
            ],
            onChanged: (v) => setState(() => _weekStart = v ?? 1),
            borderRadius: BorderRadius.circular(12),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E3E7)),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                // ★ setTarget / setWeekStart ではなく save(...) を使う
                await WeeklyGoalStore.save(target: _target, startWeekday: _weekStart);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('保存', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
