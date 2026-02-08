// lib/widgets/bmi_edit_sheet.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 使い方：
/// final result = await showBmiEditor(
///   context: context,
///   initialHeightCm: 165.0,
///   initialWeightKg: 60.0,
/// );
/// if (result != null) {
///   print(result.heightCm);
///   print(result.weightKg);
/// }

Future<_BmiResult?> showBmiEditor({
  required BuildContext context,
  required double initialHeightCm,
  required double initialWeightKg,
}) {
  return showModalBottomSheet<_BmiResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BmiEditSheet(
      initialHeightCm: initialHeightCm,
      initialWeightKg: initialWeightKg,
    ),
  );
}

class _BmiResult {
  final double heightCm;
  final double weightKg;
  const _BmiResult(this.heightCm, this.weightKg);
}

class _BmiEditSheet extends StatefulWidget {
  const _BmiEditSheet({
    super.key,
    required this.initialHeightCm,
    required this.initialWeightKg,
  });

  final double initialHeightCm;
  final double initialWeightKg;

  @override
  State<_BmiEditSheet> createState() => _BmiEditSheetState();
}

class _BmiEditSheetState extends State<_BmiEditSheet> {
  double _heightCm = 0;
  double _weightKg = 0;

  @override
  void initState() {
    super.initState();
    _heightCm = widget.initialHeightCm;
    _weightKg = widget.initialWeightKg;
  }

  double get _bmi {
    final m = _heightCm / 100.0;
    if (m <= 0) return 0;
    return _weightKg / (m * m);
  }

  String get _bmiClass {
    final b = _bmi;
    if (b < 18.5) return '低体重';
    if (b < 25.0) return '普通体重';
    if (b < 30.0) return '肥満(1度)';
    if (b < 35.0) return '肥満(2度)';
    if (b < 40.0) return '肥満(3度)';
    return '肥満(4度)';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48, height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Text('BMI の編集', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _BmiPreviewCard(
              heightCm: _heightCm,
              weightKg: _weightKg,
              bmi: _bmi,
              bmiClass: _bmiClass,
            ),
            const SizedBox(height: 8),

            // 身長メーター
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _MeterCard(
                title: '身長',
                unit: 'cm',
                dial: ValueDial(
                  value: _heightCm,
                  min: 120.0,
                  max: 220.0,
                  step: 0.1,
                  labelBuilder: (v) => v.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _heightCm = v),
                ),
                subtitle: '円形メーターをドラッグして調整できます',
              ),
            ),

            // 体重メーター
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _MeterCard(
                title: '体重',
                unit: 'kg',
                dial: ValueDial(
                  value: _weightKg,
                  min: 30.0,
                  max: 200.0,
                  step: 0.1,
                  labelBuilder: (v) => v.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _weightKg = v),
                ),
                subtitle: '円形メーターをドラッグして調整できます',
              ),
            ),

            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, _BmiResult(_heightCm, _weightKg));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('保存する'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BmiPreviewCard extends StatelessWidget {
  const _BmiPreviewCard({
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
    required this.bmiClass,
  });

  final double heightCm;
  final double weightKg;
  final double bmi;
  final String bmiClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = const Color(0xFF2962FF);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _Stat(title: '身長', value: '${heightCm.toStringAsFixed(1)} cm'),
          const SizedBox(width: 12),
          _Stat(title: '体重', value: '${weightKg.toStringAsFixed(1)} kg'),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('BMI', style: theme.textTheme.labelMedium),
              Text(bmi.toStringAsFixed(1),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: accent,
                  )),
              Text(bmiClass, style: theme.textTheme.labelMedium),
            ],
          )
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MeterCard extends StatelessWidget {
  const _MeterCard({
    required this.title,
    required this.unit,
    required this.dial,
    this.subtitle,
  });

  final String title;
  final String unit;
  final Widget dial;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title（$unit）', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
            ],
            const SizedBox(height: 8),
            Center(child: SizedBox(height: 240, width: 240, child: dial)),
          ],
        ),
      ),
    );
  }
}

/// ドラッグで値を変更できる円形メーター（ダイアル）
class ValueDial extends StatefulWidget {
  const ValueDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.labelBuilder,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String Function(double)? labelBuilder;

  @override
  State<ValueDial> createState() => _ValueDialState();
}

class _ValueDialState extends State<ValueDial> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(widget.min, widget.max);
  }

  @override
  void didUpdateWidget(covariant ValueDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value = widget.value.clamp(widget.min, widget.max);
  }

  double get _t {
    final span = (widget.max - widget.min);
    if (span <= 0) return 0;
    return (_value - widget.min) / span; // 0..1
  }

  double _snap(double v) {
    final min = widget.min;
    final max = widget.max;
    final step = widget.step <= 0 ? 1.0 : widget.step;
    final snapped = ((v - min) / step).round() * step + min;
    return snapped.clamp(min, max);
  }

  void _setByAngle(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = localPos - center;
    final angle = math.atan2(v.dy, v.dx); // -pi..pi (right=0)
    // 角度 -> 0..1（上を0にしたい場合はstart角度をずらす）
    double t = (angle + math.pi) / (2 * math.pi); // 0..1
    final value = widget.min + t * (widget.max - widget.min);
    final snapped = _snap(value);
    HapticFeedback.selectionClick();
    setState(() => _value = snapped);
    widget.onChanged(snapped);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        onPanStart: (d) => _setByAngle(d.localPosition, Size(c.maxWidth, c.maxHeight)),
        onPanUpdate: (d) => _setByAngle(d.localPosition, Size(c.maxWidth, c.maxHeight)),
        onTapDown: (d) => _setByAngle(d.localPosition, Size(c.maxWidth, c.maxHeight)),
        child: CustomPaint(
          painter: _DialPainter(progress: _t),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  widget.labelBuilder?.call(_value) ?? _value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text('ドラッグして調整', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress});
  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = const Color(0x11000000);

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14
      ..color = const Color(0xFF2962FF);

    // ベース円
    canvas.drawCircle(center, radius, base);

    // 進捗アーク：上(-pi/2)から時計回り
    final start = -math.pi / 2;
    final sweep = progress * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, start, sweep, false, active);

    // 目盛り
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x33000000);
    for (int i = 0; i < 40; i++) {
      final t = i / 40.0;
      final ang = start + t * 2 * math.pi;
      final inner = center + Offset(math.cos(ang), math.sin(ang)) * (radius - 10);
      final outer = center + Offset(math.cos(ang), math.sin(ang)) * (radius + 2);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // ノブ
    final knobAng = start + sweep;
    final knobCenter = center + Offset(math.cos(knobAng), math.sin(knobAng)) * radius;
    final knob = Paint()..color = const Color(0xFF2962FF);
    canvas.drawCircle(knobCenter, 8, knob);
    canvas.drawCircle(knobCenter, 12, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x332962FF));
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
