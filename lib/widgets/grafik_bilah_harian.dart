import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/statistik.dart';

/// Bilah capaian per hari untuk sepekan terakhir.
///
/// Satu seri saja, jadi warnanya satu rona (tanpa legenda): yang dibandingkan
/// besarannya, bukan identitasnya. Kisi hanya horizontal dan setipis mungkin.
class GrafikBilahHarian extends StatelessWidget {
  const GrafikBilahHarian({super.key, required this.harian});

  final List<RingkasanHarian> harian;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return SizedBox(
      height: 196,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 100,
          alignment: BarChartAlignment.spaceBetween,
          barGroups: [
            for (var i = 0; i < harian.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: harian[i].skor * 100,
                    color: VizPalet.selCapaian(
                      context,
                      harian[i].skor,
                      adaCatatan: harian[i].adaCatatan,
                    ),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: VizPalet.jejak(context),
                    ),
                  ),
                ],
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
                // Label dua baris (nama hari + tanggal) perlu ruang lebih
                // besar dari bawaan 30, jika tidak Column-nya meluap.
                reservedSize: 44,
                getTitlesWidget: (nilai, meta) {
                  final indeks = nilai.round();
                  if (indeks < 0 || indeks >= harian.length) {
                    return const SizedBox.shrink();
                  }
                  final tanggal = harian[indeks].tanggal;
                  final ini = tanggalSama(tanggal, hariIni());
                  return SideTitleWidget(
                    meta: meta,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatHariSingkat(tanggal),
                          style: teks.labelSmall?.copyWith(
                            color: ini
                                ? skema.onSurface
                                : VizPalet.tintaRedup(context),
                            fontWeight: ini ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${tanggal.day}',
                          style: teks.labelSmall?.copyWith(
                            fontSize: 10,
                            color: VizPalet.tintaRedup(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => skema.inverseSurface,
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              getTooltipItem: (grup, indeksGrup, rod, indeksRod) {
                if (indeksGrup < 0 || indeksGrup >= harian.length) return null;
                final hari = harian[indeksGrup];
                return BarTooltipItem(
                  '${formatTanggalSingkat(hari.tanggal)}\n',
                  TextStyle(
                    color: skema.onInverseSurface.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${hari.persen}% · '
                          '${hari.jumlahSelesai}/${hari.jumlahAmalan} amalan',
                      style: TextStyle(
                        color: skema.onInverseSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
