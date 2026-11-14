import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Histogramme simple : une barre par libellé.
///
/// Graduations entières sans doublon, largeur limitée à [maxWidth] et centrée,
/// description textuelle des valeurs pour les lecteurs d'écran.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.height = 180,
    this.maxWidth = 560,
    this.semanticLabel,
  }) : assert(labels.length == values.length);

  final List<String> labels;
  final List<int> values;
  final double height;
  final double maxWidth;

  /// Préfixe de la description lue par les lecteurs d'écran.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxValue = values.isEmpty ? 0 : values.reduce(max);
    // Intervalle entier ; le maximum de l'axe est un multiple de l'intervalle
    // strictement supérieur à la plus grande valeur (0, 1, 2 et non 1, 1, 0).
    final interval = max(1, (max(maxValue, 1) / 4).ceil());
    final maxY = (interval * ((max(maxValue, 1) * 1.1) / interval).ceil()).toDouble();
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final description = [
      if (semanticLabel != null) semanticLabel!,
      for (var i = 0; i < labels.length; i++) '${labels[i]} : ${values[i]}',
    ].join(', ');

    return Semantics(
      label: description,
      container: true,
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              height: height,
              child: LayoutBuilder(builder: (context, box) {
                final count = max(values.length, 1);
                final barWidth = (box.maxWidth / (count * 2.4)).clamp(14.0, 44.0);
                return BarChart(
                  BarChartData(
                    maxY: maxY,
                    minY: 0,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: interval.toDouble(),
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                          '${labels[group.x]} : ${rod.toY.toInt()}',
                          TextStyle(color: scheme.onInverseSurface),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: interval.toDouble(),
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble() ||
                                value.toInt() % interval != 0) {
                              return const SizedBox.shrink();
                            }
                            return Text(value.toInt().toString(), style: small);
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(labels[i], style: small),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < values.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: values[i].toDouble(),
                            width: barWidth,
                            color: scheme.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ]),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
