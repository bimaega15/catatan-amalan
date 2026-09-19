import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/statistik.dart';
import '../state/amalan_controller.dart';
import '../widgets/kalender_capaian.dart';
import '../widgets/umum.dart';

/// Riwayat bulanan dalam bentuk kalender berwarna, bisa ditelusuri per hari.
class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kontroler = context.watch<AmalanController>();
    final bulan = kontroler.bulanRiwayat;
    final harian = kontroler.ringkasanBulan();
    final ini = hariIni();

    final tercatat = harian.where((h) => h.adaCatatan).toList();
    final rataRata = tercatat.isEmpty
        ? 0.0
        : tercatat.fold<double>(0, (jml, h) => jml + h.skor) / tercatat.length;
    final totalSelesai = harian.fold<int>(0, (jml, h) => jml + h.jumlahSelesai);
    final bolehMaju = DateTime(
      bulan.year,
      bulan.month + 1,
    ).isBefore(DateTime(ini.year, ini.month + 1));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
              child: Text(
                'Riwayat',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            KartuPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => kontroler.geserBulanRiwayat(-1),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Bulan sebelumnya',
                      ),
                      Expanded(
                        child: Text(
                          formatBulanTahun(bulan),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: bolehMaju
                            ? () => kontroler.geserBulanRiwayat(1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Bulan berikutnya',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  KalenderCapaian(
                    bulan: bulan,
                    harian: harian,
                    onPilihHari: (hari) =>
                        _bukaDetail(context, kontroler, hari),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Dua kartu per baris: tiga kartu berdampingan membuat labelnya
            // terpangkas pada lebar ponsel. IntrinsicHeight memberi Row tinggi
            // terbatas, syarat agar stretch menyamakan tinggi kartu.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: KartuAngka(
                      nilai: '${(rataRata * 100).round()}%',
                      label: 'Rata-rata',
                      keterangan: 'Dari hari yang tercatat',
                      ikon: Icons.speed_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KartuAngka(
                      nilai: '${tercatat.length}',
                      label: 'Hari tercatat',
                      keterangan: 'Ada amalan dikerjakan',
                      ikon: Icons.edit_calendar_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: KartuAngka(
                      nilai: '${harian.where((h) => h.tuntas).length}',
                      label: 'Hari tuntas',
                      keterangan: 'Semua amalan selesai',
                      ikon: Icons.verified_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KartuAngka(
                      nilai: '$totalSelesai',
                      label: 'Amalan tuntas',
                      keterangan: 'Total sepanjang bulan ini',
                      ikon: Icons.task_alt,
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

  Future<void> _bukaDetail(
    BuildContext context,
    AmalanController kontroler,
    RingkasanHarian hari,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => _DetailHari(kontroler: kontroler, hari: hari),
    );
  }
}

class _DetailHari extends StatelessWidget {
  const _DetailHari({required this.kontroler, required this.hari});

  final AmalanController kontroler;
  final RingkasanHarian hari;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final daftar = kontroler.amalanPada(hari.tanggal);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, kontrolerGulir) => ListView(
        controller: kontrolerGulir,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            formatTanggalPanjang(hari.tanggal),
            style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${hari.persen}% capaian · '
            '${hari.jumlahSelesai} dari ${hari.jumlahAmalan} amalan tuntas',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (daftar.isEmpty)
            Text(
              'Belum ada amalan yang berlaku pada tanggal ini.',
              style: teks.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
            )
          else
            for (final amalan in daftar)
              Builder(
                builder: (context) {
                  final jumlah = kontroler.capaian(amalan, hari.tanggal);
                  final selesai = amalan.selesaiDengan(jumlah);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      amalan.ikonData,
                      color: VizPalet.kategori(context, amalan.kategori),
                    ),
                    title: Text(amalan.nama),
                    subtitle: amalan.berupaHitungan
                        ? Text('$jumlah / ${amalan.target} ${amalan.satuan}')
                        : null,
                    trailing: Icon(
                      selesai
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selesai ? skema.primary : skema.outlineVariant,
                    ),
                  );
                },
              ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              kontroler.pilihTanggal(hari.tanggal);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Buka & ubah hari ini'),
          ),
        ],
      ),
    );
  }
}
