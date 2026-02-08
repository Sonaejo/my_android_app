// lib/widgets/number_dial_sheet.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 度→ラジアン
double _rad(double deg) => deg * math.pi / 180.0;

/// step から小数桁数を推定（0.1→1桁、0.25→2桁、1→0桁）
int _decimalsFromStep(double step) {
  int d = 0;
  double s = step;
  while ((s - s.roundToDouble()).abs() > 1e-10 && d < 6) {
    s *= 10;
    d++;
  }
  return d.clamp(0, 6);
}

/// 任意の値 v を [min, max] にクランプし、step にスナップ
double _snapToStep(double v, double min, double max, double step) {
  final q = ((v - min) / step).round();
  final s = min + q * step;
  final clamped = s.clamp(min, max);
  final dec = _decimalsFromStep(step);
  return double.parse((clamped as double).toStringAsFixed(dec));
}

/// ダイヤル＋手入力の編集ダイアログを開く
Future<double?> showNumberDialEditor({
  required BuildContext context,
  required String title,
  required String unit,
  required double initial,
  required double min,
  required double max,
  required double step,
  String Function(double v)? labelBuilder,
}) {
  return showDialog<double>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _NumberDialDialog(
      title: title,
      unit: unit,
      initial: initial.clamp(min, max),
      min: min,
      max: max,
      step: step,
      labelBuilder: labelBuilder ?? (v) => v.toStringAsFixed(_decimalsFromStep(step)),
    ),
  );
}

class _NumberDialDialog extends StatefulWidget {
  const _NumberDialDialog({
    required this.title,
    required this.unit,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
    required this.labelBuilder,
  });

  final String title;
  final String unit;
  final double initial, min, max, step;
  final String Function(double) labelBuilder;

  @override
  State<_NumberDialDialog> createState() => _NumberDialDialogState();
}

class _NumberDialDialogState extends State<_NumberDialDialog> {
  late double _value;
  late TextEditingController _ctrl;
  late int _decimals;

  @override
  void initState() {
    super.initState();
    _decimals = _decimalsFromStep(widget.step);
    _value = _snapToStep(widget.initial, widget.min, widget.max, widget.step);
    _ctrl = TextEditingController(text: _format(_value));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _format(double v) => v.toStringAsFixed(_decimals);

  /// 確定操作で使う：スナップ＆整形（TextFieldは確定時のみ上書き）
  void _applyValue(double v) {
    final snapped = _snapToStep(v, widget.min, widget.max, widget.step);
    setState(() => _value = snapped);

    final t = _format(snapped);
    _ctrl.value = _ctrl.value.copyWith(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
      composing: TextRange.empty,
    );
  }

  void _onChangedFromDial(double v) => _applyValue(v);
  void _stepAdd(int dir) => _applyValue(_value + dir * widget.step);

  /// 入力“中”はテキストをいじらない。パースできたら生値だけ反映（未確定）
  void _onTextChanged(String s) {
    final str = s.replaceAll(',', '.').replaceAll('．', '.');
    if (str.trim().isEmpty) return;
    final p = double.tryParse(str);
    if (p == null) return;
    setState(() => _value = p.clamp(widget.min, widget.max));
  }

  /// Enter / フォーカス外れで確定
  void _onSubmit() {
    final p = double.tryParse(_ctrl.text.replaceAll(',', '.').replaceAll('．', '.'));
    if (p == null) return;
    _applyValue(p);
  }

    @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final media = MediaQuery.of(context);
    final maxH = media.size.height * 0.86; // 画面の86%までに制限（好みで0.9でもOK）

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: maxH, // ★これが重要：画面内に収める
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            // ★キーボードが出ても中身だけスクロールできる
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ハンドル
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFE4EA),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _NumberDial(
                    value: _value,
                    min: widget.min,
                    max: widget.max,
                    step: widget.step,
                    onChanged: _onChangedFromDial,
                    unit: widget.unit,
                    labelBuilder: widget.labelBuilder,
                    accent: cs.primary,
                  ),

                  const SizedBox(height: 8),

                  _InlineInputRow(
                    controller: _ctrl,
                    unit: widget.unit,
                    decimals: _decimals,
                    onChanged: _onTextChanged,
                    onSubmitted: _onSubmit,
                    onMinus: () => _stepAdd(-1),
                    onPlus: () => _stepAdd(1),
                    min: widget.min,
                    max: widget.max,
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('キャンセル'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(_value),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 手入力 + ステッパー UI
class _InlineInputRow extends StatelessWidget {
  const _InlineInputRow({
    required this.controller,
    required this.unit,
    required this.decimals,
    required this.onChanged,
    required this.onSubmitted,
    required this.onMinus,
    required this.onPlus,
    required this.min,
    required this.max,
  });

  final TextEditingController controller;
  final String unit;
  final int decimals;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onMinus, onPlus;
  final double min, max;

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFCDD6E3)),
    );

    return Row(
      children: [
        _RoundIconBtn(icon: Icons.remove, onTap: onMinus),
        const SizedBox(width: 10),
        Expanded(
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) onSubmitted(); // フォーカス外れで確定
            },
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              inputFormatters: [
                // 数字、ピリオド、カンマ、全角．を許可
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.\uFF0E]')),
              ],
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                isDense: true,
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(color: Color(0xFF2962FF)),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(unit, style: const TextStyle(color: Colors.black54)),
                ),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              onChanged: onChanged,
              onEditingComplete: onSubmitted,        // IME完了
              onSubmitted: (_) => onSubmitted(),     // 物理Enter
            ),
          ),
        ),
        const SizedBox(width: 10),
        _RoundIconBtn(icon: Icons.add, onTap: onPlus),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE9F0FF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44, height: 44,
          child: Icon(icon, color: const Color(0xFF4C6EF5)),
        ),
      ),
    );
  }
}

/// 円形ダイヤル（カーソル位置とノブが一致）
/// globalPosition → dial RenderBox の local に変換して角度計算。
class _NumberDial extends StatefulWidget {
  const _NumberDial({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.unit,
    required this.labelBuilder,
    required this.accent,
  });

  final double value, min, max, step;
  final ValueChanged<double> onChanged;
  final String unit;
  final String Function(double) labelBuilder;
  final Color accent;

  @override
  State<_NumberDial> createState() => _NumberDialState();
}

class _NumberDialState extends State<_NumberDial> {
  final GlobalKey _dialKey = GlobalKey();

  // 見た目パラメータ
  static const double _size = 280;
  static const double _track = 18;
  static const double _gapDegrees = 80;
  static const double _tickLenLong = 10;
  static const double _tickLenShort = 4;
  static const int _ticks = 60;

  double get _startAngle => _rad(90 + _gapDegrees / 2);   // 左下
  double get _endAngle   => _rad(450 - _gapDegrees / 2);  // 右下
  double get _sweep      => _endAngle - _startAngle;

  // 値→角度
  double _angleFromValue(double v) {
    final t = ((v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return _startAngle + _sweep * t;
  }

    // startAngle基準で「a」を連続角度にする（0..2piの巻き戻りを吸収）
  double _unwrapToStart(double a) {
    double aa = a;
    while (aa < _startAngle) aa += 2 * math.pi;
    while (aa >= _startAngle + 2 * math.pi) aa -= 2 * math.pi;
    return aa;
  }

  bool _isWithinArc(double a) {
    final aa = _unwrapToStart(a);
    return aa >= _startAngle && aa <= _startAngle + _sweep;
  }

  double _angDist(double a, double b) {
    double aa = a % (2 * math.pi);
    double bb = b % (2 * math.pi);
    double d = (aa - bb).abs();
    if (d > math.pi) d = 2 * math.pi - d;
    return d;
  }

  // 角度→値（ギャップ側は端にスナップ）※2pi跨ぎ対応版
  double _valueFromAngle(double a) {
    // 入力 angle は 0..2pi
    final aa0 = a % (2 * math.pi);

    // ギャップなら近い端へ吸着（距離比較）
    final distToStart = _angDist(aa0, _startAngle);
    final distToEnd   = _angDist(aa0, _endAngle);

    double aa = aa0;
    if (!_isWithinArc(aa)) {
      // ★ここ重要：%2piしない（unwrapの基準がズレるのを防ぐ）
      aa = (distToStart < distToEnd) ? _startAngle : _endAngle;
    }

    final aCont = _unwrapToStart(aa);
    final t = ((aCont - _startAngle) / _sweep).clamp(0.0, 1.0);

    final v = widget.min + (widget.max - widget.min) * t;
    return v.clamp(widget.min, widget.max);
  }

  // ★ドラッグ処理：必ず _valueFromAngle を通す
  void _handlePan(Offset globalPos) {
    final ctx = _dialKey.currentContext;
    if (ctx == null) return;

    final RenderBox box = ctx.findRenderObject() as RenderBox;
    final Offset local = box.globalToLocal(globalPos);
    final Size size = box.size;
    final Offset center = size.center(Offset.zero);

    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;

    double ang = math.atan2(dy, dx); // -pi..pi
    if (ang < 0) ang += 2 * math.pi; // 0..2pi

    final v = _valueFromAngle(ang);
    widget.onChanged(v);
  }



  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final label = widget.labelBuilder(value);
    final angle = _angleFromValue(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          RepaintBoundary(
            key: _dialKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown:  (d) => _handlePan(d.globalPosition),
              onPanUpdate:(d) => _handlePan(d.globalPosition),
              onTapDown:  (d) => _handlePan(d.globalPosition),
              child: SizedBox(
                width: _size,
                height: _size,
                child: CustomPaint(
                  painter: _DialPainter(
                    startAngle: _startAngle,
                    endAngle: _endAngle,
                    sweep: _sweep,
                    ticks: _ticks,
                    tickLenLong: _tickLenLong,
                    tickLenShort: _tickLenShort,
                    track: _track,
                    accent: widget.accent,
                    valueAngle: angle,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('ドラッグして調整', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 8),
                        Text(widget.unit, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.startAngle,
    required this.endAngle,
    required this.sweep,
    required this.ticks,
    required this.tickLenLong,
    required this.tickLenShort,
    required this.track,
    required this.accent,
    required this.valueAngle,
  });

  final double startAngle, endAngle, sweep;
  final int ticks;
  final double tickLenLong, tickLenShort, track;
  final Color accent;
  final double valueAngle;

  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    final outerR = math.min(s.width, s.height) / 2 - 6;
    final innerR = outerR - track;

    // 背景トラック
    final bg = Paint()
      ..color = const Color(0xFFE9EDF3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = track
      ..strokeCap = StrokeCap.round;

    c.drawArc(
      Rect.fromCircle(center: center, radius: (innerR + outerR) / 2),
      startAngle,
      sweep,
      false,
      bg,
    );

    // アクティブアーク（現在値まで）
    final active = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = track
      ..strokeCap = StrokeCap.round;

    final valSweep = _arcSweepForValue();
    c.drawArc(
      Rect.fromCircle(center: center, radius: (innerR + outerR) / 2),
      startAngle,
      valSweep,
      false,
      active,
    );

    // 目盛り
    final tickPaint = Paint()
      ..color = const Color(0xFFCBD3E1)
      ..strokeWidth = 2;

    for (int i = 0; i <= ticks; i++) {
      final t = i / ticks;
      final ang = startAngle + sweep * t;
      final isLong = (i % 10 == 0);
      final len = isLong ? tickLenLong : tickLenShort;

      final p1 = Offset(
        center.dx + math.cos(ang) * (outerR + 2),
        center.dy + math.sin(ang) * (outerR + 2),
      );
      final p2 = Offset(
        center.dx + math.cos(ang) * (outerR + 2 + len),
        center.dy + math.sin(ang) * (outerR + 2 + len),
      );
      c.drawLine(p1, p2, tickPaint);
    }

    // ノブ
    final knobR = (innerR + outerR) / 2;
    final knob = Offset(
      center.dx + math.cos(valueAngle) * knobR,
      center.dy + math.sin(valueAngle) * knobR,
    );
    c.drawCircle(knob, 10, Paint()..color = Colors.white);
    c.drawCircle(knob, 10, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = accent);
  }

  double _arcSweepForValue() {
    double aa = valueAngle;
    while (aa < startAngle) aa += 2 * math.pi;
    return (aa - startAngle).clamp(0.0, sweep);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.valueAngle != valueAngle ||
      old.accent != accent ||
      old.startAngle != startAngle ||
      old.endAngle != endAngle ||
      old.ticks != ticks;
}
