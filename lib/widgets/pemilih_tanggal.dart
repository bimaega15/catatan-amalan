import 'package:flutter/material.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';

/// Deretan hari yang bisa digulir mendatar, hari ini berada paling kanan.
///
/// Tiap kepingan membawa garis kecil berwarna tangga capaian, sehingga naik
/// turunnya sepekan terakhir sudah terbaca sebelum masuk ke halaman statistik.
class PemilihTanggal extends StatelessWidget {
  const PemilihTanggal({
    super.key,
    required this.tanggalAktif,
    required this.onPilih,
    required this.skorHari,
    this.jumlahHari = 30,
  });

  final DateTime tanggalAktif;
  final ValueChanged<DateTime> onPilih;

  /// Capaian 0..1 untuk satu hari, dipakai mewarnai garis penanda.
  final double Function(DateTime) skorHari;
  final int jumlahHari;

  @override
  Widget build(BuildContext context) {
    final ini = hariIni();

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: jumlahHari,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, indeks) {
          final tanggal = ini.subtract(Duration(days: indeks));
          return _KepingHari(
            tanggal: tanggal,
            terpilih: tanggalSama(tanggal, tanggalAktif),
            hariIni: indeks == 0,
            skor: skorHari(tanggal),
            onTekan: () => onPilih(tanggal),
          );
        },
      ),
    );
  }
}

class _KepingHari extends StatelessWidget {
  const _KepingHari({
    required this.tanggal,
    required this.terpilih,
    required this.hariIni,
    required this.skor,
    required this.onTekan,
  });

  final DateTime tanggal;
  final bool terpilih;
  final bool hariIni;
  final double skor;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    final latar = terpilih ? skema.primary : Theme.of(context).cardTheme.color;
    final tinta = terpilih ? skema.onPrimary : skema.onSurface;

    return Material(
      color: latar,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTekan,
        child: Container(
          width: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: terpilih
                  ? skema.primary
                  : skema.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatHariSingkat(tanggal),
                style: teks.labelSmall?.copyWith(
                  color: terpilih
                      ? skema.onPrimary.withValues(alpha: 0.85)
                      : skema.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${tanggal.day}',
                style: teks.titleMedium?.copyWith(
                  color: tinta,
                  fontWeight: hariIni ? FontWeight.w800 : FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: terpilih
                      ? skema.onPrimary.withValues(alpha: skor > 0 ? 0.95 : 0.3)
                      : VizPalet.selCapaian(context, skor),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
