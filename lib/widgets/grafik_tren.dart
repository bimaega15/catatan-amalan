import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/statistik.dart';

/// Tren capaian harian sepanjang periode terpilih.
///
/// Satu seri, garis tipis 2px dengan area gradasi di bawahnya; titik hanya
/// muncul saat disentuh supaya grafik tetap lapang pada periode panjang.
class GrafikTren extends StatelessWidget {
  const GrafikTren({super.key, required this.harian});

  final List<RingkasanHarian> harian;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    if (harian.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Data belum cukup untuk menggambar tren.',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ),
      );
    }

    // Tampilkan label tanggal beberapa titik saja agar tidak bertumpuk.
    final jarakLabel = (harian.length / 5).ceil().toDouble();

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: (harian.length - 1).toDouble(),
          clipData: const FlClipData.all(),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < harian.length; i++)
                  FlSpot(i.toDouble(), harian[i].skor * 100),
              ],
              isCurved: true,
              curveSmoothness: 0.22,
              preventCurveOverShooting: true,
              color: skema.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    skema.primary.withValues(alpha: 0.22),
                    skema.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: VizPalet.kisi(context), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 50,
                reservedSize: 42,
                getTitlesWidget: (nilai, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${nilai.round()}%',
                    style: teks.labelSmall?.copyWith(
                      color: VizPalet.tintaRedup(context),
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: jarakLabel,
                getTitlesWidget: (nilai, meta) {
                  final indeks = nilai.round();
                  if (indeks < 0 || indeks >= harian.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatTanggalSingkat(harian[indeks].tanggal),
                      style: teks.labelSmall?.copyWith(
                        color: VizPalet.tintaRedup(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (barData, indeks) => indeks
                .map(
                  (_) => TouchedSpotIndicatorData(
                    FlLine(color: skema.primary, strokeWidth: 1.5),
                    FlDotData(
                      getDotPainter: (spot, persen, bar, i) =>
                          FlDotCirclePainter(
                            radius: 4.5,
                            color: skema.primary,
                            strokeWidth: 2,
                            strokeColor:
                                Theme.of(context).cardTheme.color ??
                                skema.surface,
                          ),
                    ),
                  ),
                )
                .toList(),
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => skema.inverseSurface,
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              getTooltipItems: (titikTersentuh) => titikTersentuh.map((titik) {
                final indeks = titik.x.round();
                if (indeks < 0 || indeks >= harian.length) return null;
                final hari = harian[indeks];
                return LineTooltipItem(
                  '${formatTanggalSingkat(hari.tanggal)}\n',
                  TextStyle(
                    color: skema.onInverseSurface.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '${hari.persen}% capaian',
                      style: TextStyle(
                        color: skema.onInverseSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
