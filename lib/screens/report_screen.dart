// lib/screens/report_screen.dart
import 'package:flutter/material.dart';

/// レポート画面（/report）
/// - 「履歴」セクション（タイトル/カード/日付ボタン）を押したら
///   “一週間の目標ページ（トレーニング画面）”へ戻す。
///
/// ✅ 重要：あなたのアプリで「トレーニング画面」のルートが "/" ではない場合、
/// _kWeeklyGoalRoute をそのルート名に変更してください。
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // あなたの「一週間の目標ページ（トレーニング画面）」のルート名に合わせる
  // 例: '/training' などならここを変更
  static const String _kWeeklyGoalRoute = '/';

  // ダミーデータ（ここは既存のストアに繋いでいるなら置き換えてOK）
  double _heightCm = 165.0;

  int _workouts = 15;
  double _kcal = 84.2;
  double _minutes = 18.1;
  double _seconds = 1084.8;

  // 履歴の「日付ボタン」用（スクショの 1..31 のイメージ）
  final int _daysInMonth = 31;
  int _selectedDay = 14;

  // ─────────────────────────────────────────────
  // ここが今回の変更の本体：
  // 「履歴を押したら週目標ページへ戻す」
  // ─────────────────────────────────────────────
  void _goToWeeklyGoalPage() {
    // ✅ まずは現在のNavigatorスタックを先頭まで戻す
    // （go_router / Navigator どちらの構成でも “戻れる範囲で” 安全に動く）
    Navigator.of(context).popUntil((route) => route.isFirst);

    // ✅ さらに確実に「トレーニング画面（週目標ページ）」へ寄せたい場合は pushNamed を使う
    // ただし、あなたの構成が MaterialApp.router（go_router）で “named routes が無い” 場合は
    // ここは不要です（popUntil のみでOK）。
    //
    // 「popUntilだけだと report → training に切り替わらない」場合は
    // ↓この行を有効化し、_kWeeklyGoalRoute を実際のルートに合わせてください。
    try {
      Navigator.of(context).pushNamedAndRemoveUntil(
        _kWeeklyGoalRoute,
        (route) => false,
      );
    } catch (_) {
      // named route が無い構成（MaterialApp.router等）の場合はここに来るので無視
      // ※ その場合は go_router 側で context.go('/') にするのが最適ですが、
      // このファイル単体でコンパイルを壊さないために import はしていません。
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text('レポート'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildTopMeterCard(context),
          const SizedBox(height: 16),
          _buildStatsCards(),
          const SizedBox(height: 16),

          // ✅ ここが「履歴一覧」セクション
          // タイトル行もカード全体も “週目標ページへ戻る”
          _buildHistoryCard(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTopMeterCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildHeightMeter(),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: '身長を編集',
              onPressed: () async {
                final v = await _showEditHeightDialog(context, _heightCm);
                if (v != null) setState(() => _heightCm = v);
              },
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightMeter() {
    // 見た目だけスクショ風（横バー）
    // ※ 実際のBMI等の計算を入れるならここを置換
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '身長',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: const [
                Expanded(flex: 12, child: ColoredBox(color: Color(0xFF2F6BFF))),
                Expanded(flex: 18, child: ColoredBox(color: Color(0xFF5CC7FF))),
                Expanded(flex: 40, child: ColoredBox(color: Color(0xFF4CD4A4))),
                Expanded(flex: 30, child: ColoredBox(color: Color(0xFFF7C861))),
                Expanded(flex: 30, child: ColoredBox(color: Color(0xFFF39A59))),
                Expanded(flex: 30, child: ColoredBox(color: Color(0xFFE86D6D))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_heightCm.toStringAsFixed(1)} cm',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.emoji_events_outlined,
            value: '$_workouts',
            label: 'ワークアウト数',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department_outlined,
            value: _kcal.toStringAsFixed(1),
            label: 'キロカロリー',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.timer_outlined,
            value: _minutes.toStringAsFixed(1),
            label: '合計時間（${_seconds.toStringAsFixed(1)} 秒）',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2F6BFF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    return InkWell(
      // ✅ 履歴カード全体を押しても週目標ページへ
      onTap: _goToWeeklyGoalPage,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル行も押せる（InkWell全体がonTap）
              Row(
                children: [
                  const Text(
                    '履歴',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_selectedDay',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2F6BFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
              const SizedBox(height: 12),

              // 日付ボタンのグリッド（押しても週目標ページへ）
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_daysInMonth, (i) {
                  final day = i + 1;
                  final selected = day == _selectedDay;
                  return _dayChip(
                    day: day,
                    selected: selected,
                    onTap: () {
                      // 見た目の選択だけ更新（必要なら削除OK）
                      setState(() => _selectedDay = day);

                      // ✅ そして目的通り「週目標ページへ」
                      _goToWeeklyGoalPage();
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayChip({
    required int day,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF2F6BFF) : Colors.black12,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF2F6BFF) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<double?> _showEditHeightDialog(BuildContext context, double current) async {
    final c = TextEditingController(text: current.toStringAsFixed(1));
    return showDialog<double>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('身長を編集'),
          content: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '例: 165.0',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(c.text.trim());
                if (v == null || v < 50 || v > 250) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('50〜250 の範囲で入力してください')),
                  );
                  return;
                }
                Navigator.pop(context, v);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
