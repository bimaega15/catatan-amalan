import 'package:flutter/material.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/statistik.dart';

/// Kalender satu bulan yang diwarnai menurut capaian harian (heatmap).
///
/// Warna memakai satu tangga rona: makin tinggi capaian makin pekat. Angka
/// tanggal tetap dicetak di setiap sel, jadi nilainya tidak hanya tersampaikan
/// lewat warna.
class KalenderCapaian extends StatelessWidget {
  const KalenderCapaian({
    super.key,
    required this.bulan,
    required this.harian,
    required this.onPilihHari,
  });

  final DateTime bulan;
  final List<RingkasanHarian> harian;
  final ValueChanged<RingkasanHarian> onPilihHari;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final ini = hariIni();

    // Senin sebagai kolom pertama.
    final awal = DateTime(bulan.year, bulan.month);
    final geser = awal.weekday - DateTime.monday;
    final totalSel = geser + harian.length;

    return Column(
      children: [
        Row(
          children: [
            for (final label in const ['S', 'S', 'R', 'K', 'J', 'S', 'A'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: teks.labelSmall?.copyWith(
                      color: VizPalet.tintaRedup(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 1,
          ),
          itemCount: totalSel,
          itemBuilder: (context, indeks) {
            if (indeks < geser) return const SizedBox.shrink();
            final data = harian[indeks - geser];
            return _Sel(
              data: data,
              masaDepan: data.tanggal.isAfter(ini),
              hariIni: tanggalSama(data.tanggal, ini),
              onTekan: () => onPilihHari(data),
            );
          },
        ),
        const SizedBox(height: 14),
        const _Legenda(),
      ],
    );
  }
}

class _Sel extends StatelessWidget {
  const _Sel({
    required this.data,
    required this.masaDepan,
    required this.hariIni,
    required this.onTekan,
  });

  final RingkasanHarian data;
  final bool masaDepan;
  final bool hariIni;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final latar = masaDepan
        ? Colors.transparent
        : VizPalet.selCapaian(context, data.skor, adaCatatan: data.adaCatatan);
    final tinta = masaDepan
        ? skema.onSurfaceVariant.withValues(alpha: 0.4)
        : VizPalet.tintaDiAtas(latar);

    return Tooltip(
      message: masaDepan
          ? formatTanggalPendek(data.tanggal)
          : '${formatTanggalPendek(data.tanggal)} · ${data.persen}%'
                ' (${data.jumlahSelesai}/${data.jumlahAmalan})',
      child: Material(
        color: latar,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: masaDepan ? null : onTekan,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: hariIni
                  ? Border.all(color: skema.primary, width: 2)
                  : (masaDepan
                        ? Border.all(
                            color: skema.outlineVariant.withValues(alpha: 0.4),
                          )
                        : null),
            ),
            alignment: Alignment.center,
            child: Text(
              '${data.tanggal.day}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tinta,
                fontWeight: hariIni ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final tangga = VizPalet.tangga(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Sedikit',
          style: teks.labelSmall?.copyWith(color: VizPalet.tintaRedup(context)),
        ),
        const SizedBox(width: 7),
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: VizPalet.kosong(context),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        for (final warna in tangga) ...[
          const SizedBox(width: 3),
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: warna,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
        const SizedBox(width: 7),
        Text(
          'Tuntas',
          style: teks.labelSmall?.copyWith(color: VizPalet.tintaRedup(context)),
        ),
      ],
    );
  }
}
