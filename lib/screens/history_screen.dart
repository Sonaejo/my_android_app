import 'package:flutter/material.dart';
import '../services/workout_history_store.dart';
import '../services/weekly_goal_store.dart';
import 'home_screen.dart';

/// カレンダーで実施日を色付けし、選択日の履歴一覧を表示する画面
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.initialFocusDate});
  final DateTime? initialFocusDate;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month;          // 表示中の月 (1日)
  late DateTime _selected;       // 選択日
  Set<String> _marked = <String>{};
  List<WorkoutHistoryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    final base = widget.initialFocusDate ?? DateTime.now();
    _month = DateTime(base.year, base.month, 1);
    _selected = DateTime(base.year, base.month, base.day);
    _reload();
  }

  Future<void> _reload() async {
    // 月初〜翌月初
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 1);

    final marked = await WorkoutHistoryStore.daysWithWorkout(start, end);
    final list = await WorkoutHistoryStore.listBetween(
      _selected,
      _selected.add(const Duration(days: 1)),
    );

    if (!mounted) return;
    setState(() {
      _marked = marked;
      _entries = list;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _selected = DateTime(_month.year, _month.month, 1);
    });
    _reload();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final days = _buildMonthDays(_month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_month.year}/${_month.month.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _WeekdayHeader(),
          const SizedBox(height: 6),
          // カレンダーグリッド
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (_, i) {
              final d = days[i];
              final inMonth = d.month == _month.month;
              final isSel = _isSameDay(d, _selected);
              final isMarked = _marked.contains(_iso(d));

              final bg = isSel
                  ? HomeScreen.accentBlue
                  : (isMarked ? HomeScreen.accentBlue.withOpacity(0.22) : Colors.white);

              final fg = isSel ? Colors.white : (inMonth ? Colors.black87 : Colors.black38);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _selected = d);
                  _reload();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? Colors.transparent : const Color(0xFFE0E3E7)),
                  ),
                  alignment: Alignment.center,
                  child: Text('${d.day}', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          _SummaryRow(entries: _entries),

          const SizedBox(height: 8),
          ..._entries.map((e) => _EntryTile(e: e)),
        ],
      ),
    );
  }

  /// 月カレンダーに並べる日付（先月末の余白〜翌月頭の余白を含む）
  List<DateTime> _buildMonthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final weekday = first.weekday; // 1=Mon..7=Sun
    final start = first.subtract(Duration(days: (weekday % 7))); // 日曜頭にそろえる
    return List.generate(42, (i) => DateTime(start.year, start.month, start.day + i));
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['日','月','火','水','木','金','土'];
    return Row(
      children: List.generate(7, (i) {
        return Expanded(
          child: Center(
            child: Text(labels[i], style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          ),
        );
      }),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.entries});
  final List<WorkoutHistoryEntry> entries;

  String _fmtMMSS(double sec) {
    final s = sec.floor().clamp(0, 359999);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final seconds = entries.fold<double>(0.0, (p, e) => p + e.sec);
    final kcal = entries.fold<double>(0.0, (p, e) => p + e.kcal);
    final reps = entries.fold<int>(0, (p, e) => p + e.reps);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E3E7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize, color: Colors.black54),
          const SizedBox(width: 8),
          Text('合計 ${entries.length} ワークアウト ・ ${_fmtMMSS(seconds)} ・ ${kcal.toStringAsFixed(1)} kcal ・ $reps 回',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.e});
  final WorkoutHistoryEntry e;

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final d = e.dateTime;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fitness_center),
        ),
        title: Text('${e.mode.toUpperCase()} ・ ${e.reps}回',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_fmt(d)}  /  ${e.sec.toStringAsFixed(0)}秒  /  ${e.kcal.toStringAsFixed(1)} kcal'),
      ),
    );
  }
}
