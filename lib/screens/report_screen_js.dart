// lib/screens/report_screen_js.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/number_dial_sheet.dart';
import '../services/bmi_store.dart';
import '../services/bmi_history_store.dart';
import '../services/workout_stats_store.dart'; // ★ 累計ワークアウト統計
import 'workout_history_screen.dart'; // ✅ 追加：履歴ページへ遷移するため

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const int kWindowDays = 90;

  List<double> _points = <double>[];
  List<DateTime> _dates = <DateTime>[];

  @override
  void initState() {
    super.initState();

    // ★ ワークアウト統計の初期化（ValueListenable に反映される）
    WorkoutStatsStore.init();

    // ★ BMI履歴の初期化
    BmiHistoryStore.init().then((_) {
      _rebuildSeries();
      setState(() {});
    });

    // 体重変化で再描画
    BmiStore.weightKg.addListener(() {
      _rebuildSeries();
      if (mounted) setState(() {});
    });

    // 履歴変化で再描画
    BmiHistoryStore.entries.addListener(() {
      _rebuildSeries();
      if (mounted) setState(() {});
    });
  }

  void _rebuildSeries() {
    final list = BmiHistoryStore.recent(days: kWindowDays);
    if (list.isEmpty) {
      _points = <double>[BmiStore.weightKg.value];
      _dates = <DateTime>[DateTime.now()];
      return;
    }
    _points = list.map((e) => e.weightKg).toList(growable: false);
    _dates = list.map((e) => e.date).toList(growable: false);
  }

  Future<void> _saveWeight(double kg) async {
    await BmiStore.setWeightKg(kg);
    await BmiHistoryStore.upsertToday(kg);
    await BmiHistoryStore.prune(keepDays: 365);
    _rebuildSeries();
    if (mounted) setState(() {});
  }

  Future<void> _saveHeight(double cm) => BmiStore.setHeightCm(cm);

  Future<void> _editWeight(BuildContext context, double currentKg) async {
    final result = await showNumberDialEditor(
      context: context,
      title: '体重を記録',
      unit: 'kg',
      initial: currentKg,
      min: 20.0,
      max: 120.0,
      step: 0.1,
      labelBuilder: (v) => v.toStringAsFixed(1),
    );
    if (result != null) await _saveWeight(result);
  }

  Future<void> _editHeight(BuildContext context, double currentCm) async {
    final result = await showNumberDialEditor(
      context: context,
      title: 'BMIを編集（身長）',
      unit: 'cm',
      initial: currentCm,
      min: 120.0,
      max: 200.0,
      step: 0.1,
      labelBuilder: (v) => v.toStringAsFixed(1),
    );
    if (result != null) await _saveHeight(result);
  }

  // ✅ 追加：履歴ページへ遷移（初期日付を渡せる）
  void _openWorkoutHistory({DateTime? initialDate}) {
    final d = initialDate ?? DateTime.now();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutHistoryScreen(initialDate: d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF4F6FA);
    final cs = Theme.of(context).colorScheme;

    // === 画面幅によるレスポンシブ判定 ==========================
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 420; // スマホ想定
    final isVeryCompact = width < 340; // さらに狭い端末
    // ===========================================================

    _LineChartPainter.overrideDates = _dates;

    final bool hasLine = _points.length >= 2;
    final double rawMin = hasLine
        ? _points.reduce(math.min)
        : (_points.isNotEmpty ? _points.first : BmiStore.weightKg.value);
    final double rawMax = hasLine
        ? _points.reduce(math.max)
        : (_points.isNotEmpty ? _points.first : BmiStore.weightKg.value);
    final minY = (rawMin - 1).floorToDouble();
    final maxY =
        (rawMax + ((rawMax - rawMin).abs() < 1e-9 ? 2 : 1)).ceilToDouble();

    // ★ サイズ縮小係数（フォント・余白・チャート高さに反映）
    final scale = isVeryCompact ? 0.85 : (isCompact ? 0.92 : 1.0);

    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: bg),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'レポート',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontSize: 18 * scale,
            ),
          ),
          backgroundColor: bg,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        bottomNavigationBar: const AppBottomNav(active: AppTab.report),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // 体重カード
              ValueListenableBuilder<double>(
                valueListenable: BmiStore.weightKg,
                builder: (_, kg, __) {
                  return _WeightCard(
                    currentKg: kg,
                    maxKg: rawMax,
                    minKg: rawMin,
                    points: _points,
                    dates: _dates,
                    accent: cs.primary,
                    minY: minY,
                    maxY: maxY,
                    onTapRecord: () => _editWeight(context, kg),
                    // レスポンシブ用
                    compact: isCompact,
                    scale: scale,
                    chartHeight: (isCompact ? 170 : 200) * scale,
                  );
                },
              ),
              SizedBox(height: 16 * scale),

              // BMIカード
              ValueListenableBuilder<double>(
                valueListenable: BmiStore.heightCm,
                builder: (_, h, __) {
                  return ValueListenableBuilder<double>(
                    valueListenable: BmiStore.weightKg,
                    builder: (_, w, __) {
                      final bmi = w / math.pow(h / 100.0, 2);
                      return _BmiCard(
                        bmi: bmi,
                        heightCm: h,
                        onTapEdit: () => _editHeight(context, h),
                        scale: scale,
                        compact: isCompact,
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 16 * scale),

              // ★ ミニ統計（ワークアウト数 / キロカロリー / 時間）
              LayoutBuilder(
                builder: (context, box) {
                  final width = box.maxWidth;
                  final bool isWide = width >= 700; // PC・タブレットなら横3列

                  if (isWide) {
                    // 横3列
                    return Row(
                      children: [
                        // ワークアウト数（int）
                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable: WorkoutStatsStore.workouts,
                            builder: (_, v, __) => _MiniStat(
                              icon: Icons.emoji_events,
                              label: 'ワークアウト数',
                              value: v.toString(),
                              scale: scale,
                            ),
                          ),
                        ),
                        SizedBox(width: 12 * scale),

                        // キロカロリー（double → 小数1桁表示）
                        Expanded(
                          child: ValueListenableBuilder<double>(
                            valueListenable: WorkoutStatsStore.kcal,
                            builder: (_, v, __) => _MiniStat(
                              icon: Icons.local_fire_department,
                              label: 'キロカロリー',
                              value: v.toStringAsFixed(1),
                              scale: scale,
                            ),
                          ),
                        ),
                        SizedBox(width: 12 * scale),

                        // 時間（seconds → 分を値、ラベルに秒も表示）
                        Expanded(
                          child: ValueListenableBuilder<double>(
                            valueListenable: WorkoutStatsStore.seconds,
                            builder: (_, sec, __) {
                              final minutes = sec / 60.0;
                              return _MiniStat(
                                icon: Icons.timer_outlined,
                                value: minutes.toStringAsFixed(1),
                                label: '合計時間（${sec.toStringAsFixed(1)} 秒）',
                                scale: scale,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 縦3列（スマホ）
                    return Column(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: WorkoutStatsStore.workouts,
                          builder: (_, v, __) => _MiniStat(
                            icon: Icons.emoji_events,
                            label: 'ワークアウト数',
                            value: v.toString(),
                            scale: scale,
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                        ValueListenableBuilder<double>(
                          valueListenable: WorkoutStatsStore.kcal,
                          builder: (_, v, __) => _MiniStat(
                            icon: Icons.local_fire_department,
                            label: 'キロカロリー',
                            value: v.toStringAsFixed(1),
                            scale: scale,
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                        ValueListenableBuilder<double>(
                          valueListenable: WorkoutStatsStore.seconds,
                          builder: (_, sec, __) {
                            final minutes = sec / 60.0;
                            return _MiniStat(
                              icon: Icons.timer_outlined,
                              value: minutes.toStringAsFixed(1),
                              label: '合計時間（${sec.toStringAsFixed(1)} 秒）',
                              scale: scale,
                            );
                          },
                        ),
                      ],
                    );
                  }
                },
              ),

              SizedBox(height: 16 * scale),

              // ✅ 変更：履歴カードを押したら履歴ページへ
              _MonthHistory(
                scale: scale,
                onOpen: () => _openWorkoutHistory(initialDate: DateTime.now()),
                onOpenDate: (d) => _openWorkoutHistory(initialDate: d),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 体重カード（折れ線＋統計）
class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.currentKg,
    required this.maxKg,
    required this.minKg,
    required this.points,
    required this.dates,
    required this.accent,
    required this.minY,
    required this.maxY,
    required this.onTapRecord,
    required this.compact,
    required this.scale,
    required this.chartHeight,
  });

  final double currentKg, maxKg, minKg, minY, maxY;
  final List<double> points;
  final List<DateTime> dates;
  final Color accent;
  final VoidCallback onTapRecord;

  final bool compact;
  final double scale;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: (compact ? 16 : 18) * scale,
      fontWeight: FontWeight.w800,
    );
    final nowNumStyle = TextStyle(
      fontSize: (compact ? 30 : 36) * scale,
      fontWeight: FontWeight.w900,
    );
    final nowUnitStyle = TextStyle(
      fontSize: (compact ? 16 : 18) * scale,
      fontWeight: FontWeight.w700,
    );

    return _Card(
      padding: EdgeInsets.all(16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル＋ボタン
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('体重', style: titleStyle),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onTapRecord,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(0, 40 * scale),
                      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                    ),
                    child: Text(
                      '記録する',
                      style: TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text('体重', style: titleStyle),
                const Spacer(),
                FilledButton(
                  onPressed: onTapRecord,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size(0, 40 * scale),
                    padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                  ),
                  child: Text(
                    '記録する',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 12 * scale),

          // 現在値＋最重/最軽
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: '現在\n',
                        style: TextStyle(
                          fontSize: 12 * scale,
                          color: Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: currentKg.toStringAsFixed(1),
                        style: nowNumStyle,
                      ),
                      TextSpan(text: 'kg', style: nowUnitStyle),
                    ],
                  ),
                ),
                SizedBox(height: 8 * scale),
                _kv('最も重い', maxKg.toStringAsFixed(1), scale),
                SizedBox(height: 4 * scale),
                _kv('最も軽い', minKg.toStringAsFixed(1), scale),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: '現在\n',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: currentKg.toStringAsFixed(1),
                        style: nowNumStyle,
                      ),
                      TextSpan(text: 'kg', style: nowUnitStyle),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('最も重い', maxKg.toStringAsFixed(1), scale),
                    _kv('最も軽い', minKg.toStringAsFixed(1), scale),
                  ],
                ),
              ],
            ),

          SizedBox(height: 12 * scale),

          // 折れ線グラフ
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                points: points,
                minY: minY,
                maxY: maxY,
                accent: accent,
                scale: scale,
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            '直近${_LineChartPainter.overrideDates?.isNotEmpty == true ? _spanLabel(_LineChartPainter.overrideDates!) : '—'}',
            style: TextStyle(color: Colors.black54, fontSize: 12 * scale),
          ),
        ],
      ),
    );
  }

  static String _spanLabel(List<DateTime> ds) {
    if (ds.isEmpty) return '';
    final a = ds.first, b = ds.last;
    final days = b.difference(DateTime(a.year, a.month, a.day)).inDays + 1;
    return '${days}日・${ds.length}件';
  }

  Widget _kv(String k, String v, double scale) => Row(
        children: [
          Text(k, style: TextStyle(color: Colors.black54, fontSize: 13 * scale)),
          SizedBox(width: 12 * scale),
          Text(
            v,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14 * scale),
          ),
        ],
      );
}

// 折れ線グラフ
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.accent,
    this.scale = 1.0,
  });

  final List<double> points;
  final double minY, maxY;
  final Color accent;
  final double scale;

  static List<DateTime>? overrideDates;

  double _niceStep(double range) {
    final target = (range <= 0 ? 1.0 : range) / 5.0;
    final mag =
        math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
    final r = target / mag;
    final base = r <= 1 ? 1 : (r <= 2) ? 2 : (r <= 5) ? 5 : 10;
    return base * mag;
  }

  @override
  void paint(Canvas c, Size s) {
    if (points.isEmpty) return;

    final left = 56.0 * scale,
        right = 12.0 * scale,
        top = 10.0 * scale,
        bottom = 38.0 * scale;
    final r = Rect.fromLTWH(
      left,
      top,
      s.width - left - right,
      s.height - top - bottom,
    );
    final safeRange = (maxY - minY).abs() < 1e-9 ? 1.0 : (maxY - minY);

    final List<DateTime> dates =
        (overrideDates != null && overrideDates!.length == points.length)
            ? overrideDates!
            : [
                for (int i = 0; i < points.length; i++)
                  DateTime.now()
                      .subtract(Duration(days: points.length - 1 - i)),
              ];

    final double startMs = dates.first.millisecondsSinceEpoch.toDouble();
    final double endMs = dates.last.millisecondsSinceEpoch.toDouble();
    final double span = (endMs - startMs).abs() < 1 ? 1 : (endMs - startMs);

    double mapXByTime(DateTime d) {
      final double t = ((d.millisecondsSinceEpoch - startMs) / span)
          .clamp(0.0, 1.0) as double;
      return r.left + r.width * t;
    }

    double mapY(double v) => r.bottom - (v - minY) / safeRange * r.height;

    final step = _niceStep(safeRange);
    final startTick = (minY / step).floor() * step;
    final endTick = (maxY / step).ceil() * step;

    final grid = Paint()
      ..color = const Color(0x11000000)
      ..style = PaintingStyle.stroke;
    for (double y = startTick; y <= endTick + 1e-9; y += step) {
      final yy = mapY(y);
      c.drawLine(Offset(r.left, yy), Offset(r.right, yy), grid);

      final tp = TextPainter(
        text: TextSpan(
          text: step < 1 ? y.toStringAsFixed(1) : y.toStringAsFixed(0),
          style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        c,
        Offset(r.left - 10 * scale - tp.width, yy - tp.height / 2),
      );
    }

    if (points.isNotEmpty) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = mapXByTime(dates[i]), y = mapY(points[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final fill = Path.from(path)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
      c.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withOpacity(0.18),
              accent.withOpacity(0.0),
            ],
          ).createShader(r),
      );

      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * scale
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );

      final endX = mapXByTime(dates.last), endY = mapY(points.last);
      c.drawCircle(
        Offset(endX, endY),
        5 * scale,
        Paint()..color = Colors.white,
      );
      c.drawCircle(
        Offset(endX, endY),
        5 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * scale
          ..color = accent,
      );

      _drawBubble(
        c,
        text: points.last.toStringAsFixed(1),
        anchor: Offset(endX, endY),
        color: const Color(0xFF2F3A56),
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 6 * scale,
        ),
      );
    }

    final Map<String, List<DateTime>> monthBuckets = {};
    for (final d in dates) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      (monthBuckets[key] ??= []).add(d);
    }
    bool firstMonth = true;
    monthBuckets.entries.forEach((e) {
      final parts = e.key.split('-');
      final y = parts[0];
      final m = int.parse(parts[1]).toString();
      final label = firstMonth ? '${y}年${m}月' : '${m}月';
      firstMonth = false;

      final centerMs =
          e.value.map((d) => d.millisecondsSinceEpoch).reduce((a, b) => a + b) /
              e.value.length;
      final xx = mapXByTime(
        DateTime.fromMillisecondsSinceEpoch(centerMs.round()),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 12 * scale,
            color: const Color(0xFF98A1B3),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(c, Offset(xx - tp.width / 2, r.top + 4 * scale));
    });

    final tickPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    final int nTicks = math.min(6, points.length.clamp(1, 999));
    for (int t = 0; t < nTicks; t++) {
      final double pos = (nTicks == 1) ? 0 : t / (nTicks - 1);
      final double ms = startMs + (endMs - startMs) * pos;
      final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms.round());
      final double x = mapXByTime(d);

      c.drawLine(
        Offset(x, r.top),
        Offset(x, r.bottom),
        Paint()
          ..color = const Color(0x0F000000)
          ..strokeWidth = 1,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: d.day.toString().padLeft(2, '0'),
          style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(x - tp.width / 2, r.bottom + 8 * scale));

      c.drawLine(
        Offset(x, r.bottom),
        Offset(x, r.bottom + 6 * scale),
        tickPaint,
      );
    }
  }

  void _drawBubble(
    Canvas c, {
    required String text,
    required Offset anchor,
    required Color color,
    required EdgeInsets padding,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13 * scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double radius = 14 * scale;
    final double tailH = 8 * scale;
    final double tailW = 10 * scale;

    final double bw = tp.width + padding.horizontal;
    final double bh = tp.height + padding.vertical;

    final Rect bubble = Rect.fromLTWH(
      anchor.dx - bw / 2,
      anchor.dy - (bh + 16 * scale),
      bw,
      bh,
    );
    final rrect = RRect.fromRectAndRadius(bubble, Radius.circular(radius));
    c.drawRRect(rrect, Paint()..color = color);

    final Path tail = Path()
      ..moveTo(anchor.dx, bubble.bottom + tailH * 0.2)
      ..lineTo(anchor.dx - tailW / 2, bubble.bottom - 1)
      ..lineTo(anchor.dx + tailW / 2, bubble.bottom - 1)
      ..close();
    c.drawPath(tail, Paint()..color = color);

    tp.paint(
      c,
      Offset(bubble.left + padding.left, bubble.top + padding.top),
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.points != points ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.accent != accent ||
      old.scale != scale;
}

///////////////////////////////////////////////////////////////////////////////
// BMI / 付帯 UI
///////////////////////////////////////////////////////////////////////////////
class _BmiCard extends StatelessWidget {
  const _BmiCard({
    required this.bmi,
    required this.heightCm,
    required this.onTapEdit,
    required this.scale,
    required this.compact,
  });
  final double bmi;
  final double heightCm;
  final VoidCallback onTapEdit;
  final double scale;
  final bool compact;

  (String label, Color color) _bmiCategory(double v) {
    if (v < 16) return ('痩せ', const Color(0xFF4C6EF5));
    if (v < 18.5) return ('やせ気味', const Color(0xFF74C0FC));
    if (v < 25) return ('正常な体重', const Color(0xFF66D9A3));
    if (v < 30) return ('やや肥満気味', const Color(0xFFF0C36E));
    if (v < 35) return ('やや肥満', const Color(0xFFF59F6E));
    return ('肥満', const Color(0xFFE57373));
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _bmiCategory(bmi);

    return _Card(
      padding: EdgeInsets.all(16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BMI',
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onTapEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(0, 40 * scale),
                      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                    ),
                    child: Text(
                      '編集',
                      style: TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  'BMI',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onTapEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size(0, 40 * scale),
                    padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                  ),
                  child: Text(
                    '編集',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 8 * scale),
          Row(
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: (compact ? 34 : 40) * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 16 * scale),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 14 * scale,
                    height: 14 * scale,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14 * scale,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          SizedBox(height: 4 * scale),
          _BmiBar(value: bmi, scale: scale).buildBar(),
          SizedBox(height: 16 * scale),
          Row(
            children: [
              Text(
                '身長',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13 * scale,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '${heightCm.toStringAsFixed(1)} cm',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14 * scale,
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                  Icon(
                    Icons.edit,
                    size: 16 * scale,
                    color: Colors.black54,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BmiBar extends StatelessWidget {
  const _BmiBar({required this.value, this.scale = 1.0});
  final double? value;
  final double scale;

  static const double _min = 15.0;
  static const double _max = 40.0;

  static const ranges = [
    _Seg(15, 16, Color(0xFF4C6EF5)),
    _Seg(16, 18.5, Color(0xFF74C0FC)),
    _Seg(18.5, 25, Color(0xFF66D9A3)),
    _Seg(25, 30, Color(0xFFF0C36E)),
    _Seg(30, 35, Color(0xFFF59F6E)),
    _Seg(35, 40, Color(0xFFE57373)),
  ];

  static const tickValues = <double>[15, 16, 18.5, 25, 30, 35, 40];

  Widget buildBar() {
    final v = value ?? 0;
    return LayoutBuilder(
      builder: (context, box) {
        final double width = box.maxWidth;
        final double barHeight = 12.0 * scale;

        double toX(double v) {
          final double t =
              (((v - _min) / (_max - _min)).clamp(0.0, 1.0) as num).toDouble();
          return t * width;
        }

        return SizedBox(
          height: 64 * scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 10 * scale,
                bottom: 28 * scale,
                child: Row(
                  children: ranges.map((s) {
                    final double seg = (s.end - s.start) / (_max - _min);
                    final double w =
                        ((seg * width).clamp(0.0, width) as num).toDouble();
                    return SizedBox(
                      width: w,
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.horizontal(
                            left: s.start == _min
                                ? Radius.circular(6 * scale)
                                : Radius.zero,
                            right: s.end == _max
                                ? Radius.circular(6 * scale)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                left: toX(v) - 7 * scale,
                top: 0,
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 24 * scale,
                  color: Colors.black87,
                ),
              ),
              ...tickValues.map((t) {
                final double x = toX(t);
                return Positioned(
                  left: x - 14 * scale,
                  bottom: 2 * scale,
                  child: SizedBox(
                    width: 28 * scale,
                    child: Text(
                      (t == 18.5) ? '18.5' : t.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => buildBar();
}

class _Seg {
  final double start, end;
  final Color color;
  const _Seg(this.start, this.end, this.color);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.scale,
  });
  final IconData icon;
  final String label, value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 18 * scale),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F0FF),
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4C6EF5),
              size: 20 * scale,
            ),
          ),
          SizedBox(width: 12 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12 * scale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHistory extends StatelessWidget {
  const _MonthHistory({
    this.scale = 1.0,
    required this.onOpen,
    required this.onOpenDate,
  });

  final double scale;

  // ✅ 追加：カード全体/見出しタップ時
  final VoidCallback onOpen;

  // ✅ 追加：日付タップ時（その日を初期日にして履歴へ）
  final void Function(DateTime date) onOpenDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final days = List.generate(
      31,
      (i) => DateTime(start.year, start.month, i + 1),
    ).where((d) => d.month == start.month).toList();

    // ✅ 変更：カードを押せるようにする（「履歴」付近＝このカード全体）
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: _Card(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 見出し行も押せる雰囲気に（右に > を追加）
            Row(
              children: [
                Text(
                  '履歴',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.black45, size: 22 * scale),
              ],
            ),

            SizedBox(height: 12 * scale),
            LayoutBuilder(
              builder: (context, box) {
                final maxW = box.maxWidth;
                double cell = 44 * scale;
                double spacing = 10 * scale;

                if (maxW < 340) {
                  cell = 36 * scale;
                  spacing = 8 * scale;
                } else if (maxW < 380) {
                  cell = 40 * scale;
                  spacing = 9 * scale;
                }

                return Wrap(
                  runSpacing: spacing,
                  spacing: spacing,
                  children: days.map((d) {
                    final isToday = d.year == now.year &&
                        d.month == now.month &&
                        d.day == now.day;

                    // ✅ 追加：日付セルをタップしたら、その日で履歴ページへ
                    return InkWell(
                      borderRadius: BorderRadius.circular(14 * scale),
                      onTap: () => onOpenDate(d),
                      child: Container(
                        width: cell,
                        height: cell,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday
                              ? const Color(0xFF2962FF).withOpacity(0.10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14 * scale),
                          border: Border.all(
                            color: isToday
                                ? const Color(0xFF2962FF)
                                : const Color(0x22000000),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              color: Color(0x10000000),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          '${d.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14 * scale,
                            color: isToday
                                ? const Color(0xFF2962FF)
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x14000000),
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
