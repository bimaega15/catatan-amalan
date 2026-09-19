import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/statistik.dart';
import '../state/amalan_controller.dart';
import '../widgets/bilah_kategori.dart';
import '../widgets/bilah_konsistensi.dart';
import '../widgets/grafik_bilah_harian.dart';
import '../widgets/grafik_tren.dart';
import '../widgets/umum.dart';

/// Ringkasan performa: angka utama, kartu ringkas, dan empat grafik.
class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kontroler = context.watch<AmalanController>();

    if (kontroler.kosong) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: KeadaanKosong(
              ikon: Icons.insights_outlined,
              judul: 'Belum ada yang diukur',
              pesan:
                  'Tambahkan amalan dan mulai mencatat. '
                  'Grafik performamu akan muncul di sini.',
            ),
          ),
        ),
      );
    }

    final performa = kontroler.performa();
    final pekan = kontroler.ringkasanPekanTerakhir();

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
                'Performa',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            _PemilihPeriode(kontroler: kontroler),
            const SizedBox(height: 16),
            _AngkaUtama(performa: performa, periode: kontroler.periode),
            const SizedBox(height: 12),
            _BarisAngka(performa: performa),
            const SizedBox(height: 20),
            KartuPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const JudulSeksi(
                    judul: 'Capaian harian',
                    keterangan: '7 hari terakhir',
                  ),
                  const SizedBox(height: 18),
                  GrafikBilahHarian(harian: pekan),
                ],
              ),
            ),
            const SizedBox(height: 14),
            KartuPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JudulSeksi(
                    judul: 'Tren capaian',
                    keterangan:
                        '${kontroler.periode.label.toLowerCase()} terakhir',
                    aksi: _LencanaPerubahan(nilai: performa.perubahan),
                  ),
                  const SizedBox(height: 14),
                  GrafikTren(harian: performa.harian),
                ],
              ),
            ),
            const SizedBox(height: 14),
            KartuPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const JudulSeksi(
                    judul: 'Porsi per kategori',
                    keterangan: 'Dari amalan yang tuntas pada periode ini',
                  ),
                  const SizedBox(height: 18),
                  BilahKategori(porsi: kontroler.porsiKategori()),
                ],
              ),
            ),
            const SizedBox(height: 14),
            KartuPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const JudulSeksi(
                    judul: 'Konsistensi per amalan',
                    keterangan: 'Berapa sering tiap amalan tuntas',
                  ),
                  const SizedBox(height: 18),
                  BilahKonsistensi(daftar: kontroler.konsistensi(), batas: 8),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Catatan(),
          ],
        ),
      ),
    );
  }
}

class _PemilihPeriode extends StatelessWidget {
  const _PemilihPeriode({required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PeriodeStatistik>(
        segments: [
          for (final periode in PeriodeStatistik.values)
            ButtonSegment(value: periode, label: Text(periode.label)),
        ],
        selected: {kontroler.periode},
        showSelectedIcon: false,
        onSelectionChanged: (pilihan) => kontroler.pilihPeriode(pilihan.first),
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

/// Angka utama halaman: rata-rata capaian pada periode terpilih.
class _AngkaUtama extends StatelessWidget {
  const _AngkaUtama({required this.performa, required this.periode});

  final PerformaRentang performa;
  final PeriodeStatistik periode;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final tingkat = performa.tingkat;

    return KartuPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rata-rata capaian · ${periode.label}',
                      style: teks.labelMedium?.copyWith(
                        color: skema.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(performa.rataRataSkor * 100).round()}%',
                      style: teks.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              LencanaStatus(
                label: tingkat.label,
                warna: tingkat.warna,
                ikon: tingkat.ikon,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tingkat.saran,
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BarisAngka extends StatelessWidget {
  const _BarisAngka({required this.performa});

  final PerformaRentang performa;

  @override
  Widget build(BuildContext context) {
    final kartu = [
      KartuAngka(
        nilai: '${performa.streakSaatIni}',
        label: 'Hari beruntun',
        keterangan: 'Capaian minimal 80% per hari',
        ikon: Icons.local_fire_department_outlined,
      ),
      KartuAngka(
        nilai: '${performa.hariTuntas}',
        label: 'Hari tuntas',
        keterangan: 'Semua amalan selesai',
        ikon: Icons.verified_outlined,
      ),
      KartuAngka(
        nilai: '${performa.totalSelesai}',
        label: 'Amalan tuntas',
        keterangan: 'Total pada periode ini',
        ikon: Icons.task_alt,
      ),
      KartuAngka(
        nilai: '${performa.streakTerpanjang}',
        label: 'Rekor beruntun',
        keterangan: 'Dalam periode ini',
        ikon: Icons.emoji_events_outlined,
      ),
    ];

    // IntrinsicHeight memberi tinggi terbatas pada Row, syarat agar
    // CrossAxisAlignment.stretch menyamakan tinggi kartu di dalam ListView.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: kartu[0]),
              const SizedBox(width: 12),
              Expanded(child: kartu[1]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: kartu[2]),
              const SizedBox(width: 12),
              Expanded(child: kartu[3]),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selisih paruh akhir dibanding paruh awal periode.
class _LencanaPerubahan extends StatelessWidget {
  const _LencanaPerubahan({required this.nilai});

  final double nilai;

  @override
  Widget build(BuildContext context) {
    final persen = (nilai * 100).round();
    if (persen == 0) {
      return LencanaStatus(
        label: 'Stabil',
        warna: Theme.of(context).colorScheme.onSurfaceVariant,
        ikon: Icons.trending_flat,
      );
    }

    final naik = persen > 0;
    return LencanaStatus(
      label: '${naik ? '+' : ''}$persen%',
      warna: naik
          ? TingkatPerforma.istiqomah.warna
          : TingkatPerforma.perluSemangat.warna,
      ikon: naik ? Icons.trending_up : Icons.trending_down,
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: skema.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Setiap amalan berbobot sama, dan capaian sebagian tetap dihitung: '
            'mengerjakan 50 dari 100 istighfar bernilai setengah untuk amalan '
            'itu. Amalan yang diarsipkan berhenti dihitung sejak tanggal '
            'pengarsipan, tanpa mengubah riwayat lama.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
