import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';

/// 近 90 天體重趨勢 + 「記錄體重」按鈕。
class WeightTrendCard extends ConsumerWidget {
  const WeightTrendCard({super.key, required this.onLog, this.targetKg});

  final VoidCallback? onLog;
  final double? targetKg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weightHistoryProvider).value ?? const [];
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('體重趨勢', style: theme.textTheme.titleMedium),
                ),
                FilledButton.tonalIcon(
                  key: const Key('log_weight_button'),
                  icon: const Icon(Icons.monitor_weight_outlined),
                  label: const Text('記錄體重'),
                  onPressed: onLog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(key: const Key('weight_summary'), _summary(history)),
            if (history.length >= 2) ...[
              const SizedBox(height: 12),
              Semantics(
                label: '近 90 天體重折線圖',
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _WeightChartPainter(
                      history,
                      targetKg: targetKg,
                      line: theme.colorScheme.primary,
                      muted: theme.colorScheme.outline,
                      labelStyle: theme.textTheme.bodySmall!,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _summary(List<BodyMeasurement> h) {
    if (h.isEmpty) return '近 90 天沒有體重紀錄';
    final last = h.last.weightKg;
    final target = targetKg == null ? '' : ' · 目標 ${_kg(targetKg!)}';
    if (h.length == 1) return '目前 ${_kg(last)}$target';

    final diff = last - h.first.weightKg;
    final days = h.last.measuredAt.difference(h.first.measuredAt).inDays;
    final change = diff.abs() < 0.05
        ? '持平'
        : '${diff < 0 ? '減少' : '增加'} ${_kg(diff.abs())}';
    return '目前 ${_kg(last)}，${days == 0 ? '今天' : '$days 天內'}$change$target';
  }

  static String _kg(double v) => '${v.toStringAsFixed(1)} 公斤';
}

/// 簡單折線圖：x 依時間、y 依體重，左側標最高／最低值，有目標體重時畫虛線。
class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter(
    this.points, {
    required this.targetKg,
    required this.line,
    required this.muted,
    required this.labelStyle,
  });

  final List<BodyMeasurement> points;
  final double? targetKg;
  final Color line;
  final Color muted;
  final TextStyle labelStyle;

  static const _labelWidth = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final weights = [for (final p in points) p.weightKg, ?targetKg];
    // 上下各留 0.5 公斤，平線時也不會除以零
    final lo = weights.reduce(math.min) - 0.5;
    final hi = weights.reduce(math.max) + 0.5;
    final t0 = points.first.measuredAt.millisecondsSinceEpoch;
    final span = math.max(
      1,
      points.last.measuredAt.millisecondsSinceEpoch - t0,
    );
    final w = size.width - _labelWidth;

    double y(double kg) => (hi - kg) / (hi - lo) * size.height;
    Offset at(DateTime t, double kg) =>
        Offset(_labelWidth + (t.millisecondsSinceEpoch - t0) / span * w, y(kg));

    _label(canvas, hi.toStringAsFixed(1), 0);
    _label(canvas, lo.toStringAsFixed(1), size.height - 14);

    if (targetKg != null) {
      final paint = Paint()
        ..color = muted
        ..strokeWidth = 1;
      for (var x = _labelWidth; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y(targetKg!)),
          Offset(math.min(x + 4, size.width), y(targetKg!)),
          paint,
        );
      }
    }

    final offsets = [for (final p in points) at(p.measuredAt, p.weightKg)];
    canvas.drawPoints(
      PointMode.polygon,
      offsets,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (final o in offsets) {
      canvas.drawCircle(o, 3, dot);
    }
  }

  void _label(Canvas canvas, String text, double top) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(color: muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _labelWidth - 4);
    tp.paint(canvas, Offset(0, top));
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.points != points || old.targetKg != targetKg || old.line != line;
}
