import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/amalan.dart';
import '../data/models/statistik.dart';
import '../state/amalan_controller.dart';
import '../widgets/kartu_amalan.dart';
import '../widgets/meter_capaian.dart';
import '../widgets/pemilih_tanggal.dart';
import '../widgets/umum.dart';
import 'form_amalan.dart';
import 'pengaturan_screen.dart';

/// Daftar amalan untuk satu hari, lengkap dengan ringkasan capaiannya.
class BerandaScreen extends StatelessWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kontroler = context.watch<AmalanController>();
    final ringkasan = kontroler.ringkasan();
    final grup = kontroler.amalanPerWaktu();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        // Kedua halaman menampilkan FAB sekaligus di dalam IndexedStack, jadi
        // tag Hero-nya harus beda; kalau sama, membuka halaman lain melempar
        // galat "multiple heroes share the same tag".
        heroTag: 'fab-beranda',
        onPressed: () => bukaFormAmalan(context),
        icon: const Icon(Icons.add),
        label: const Text('Amalan'),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Kepala(kontroler: kontroler)),
            SliverToBoxAdapter(
              child: PemilihTanggal(
                tanggalAktif: kontroler.tanggalAktif,
                onPilih: kontroler.pilihTanggal,
                skorHari: (tanggal) => kontroler.ringkasan(tanggal).skor,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _KartuHero(
                  ringkasan: ringkasan,
                  streak: kontroler.streak,
                  tanggal: kontroler.tanggalAktif,
                ),
              ),
            ),
            if (grup.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: KeadaanKosong(
                    ikon: Icons.playlist_add_check_circle_outlined,
                    judul: 'Belum ada amalan',
                    pesan:
                        'Tambahkan amalan harian pertamamu, '
                        'misalnya dzikir pagi atau tilawah.',
                    aksi: FilledButton.icon(
                      onPressed: () => bukaFormAmalan(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah amalan'),
                    ),
                  ),
                ),
              )
            else
              for (final entri in grup.entries)
                _SeksiWaktu(
                  waktu: entri.key,
                  daftar: entri.value,
                  kontroler: kontroler,
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sapaanWaktu(DateTime.now()),
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Catatan Amalan',
                  style: teks.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pilih tanggal',
            onPressed: () => _pilihTanggal(context, kontroler),
            icon: const Icon(Icons.event_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PengaturanScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          _MenuHari(kontroler: kontroler),
        ],
      ),
    );
  }

  Future<void> _pilihTanggal(
    BuildContext context,
    AmalanController kontroler,
  ) async {
    final pilihan = await showDatePicker(
      context: context,
      initialDate: kontroler.tanggalAktif,
      firstDate: DateTime(2020),
      lastDate: hariIni(),
      helpText: 'Pilih tanggal catatan',
    );
    if (pilihan != null) kontroler.pilihTanggal(pilihan);
  }
}

class _MenuHari extends StatelessWidget {
  const _MenuHari({required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Aksi lain',
      icon: const Icon(Icons.more_vert),
      onSelected: (nilai) async {
        switch (nilai) {
          case 'hari-ini':
            kontroler.kembaliKeHariIni();
          case 'tuntas':
            await kontroler.tuntaskanSemua();
          case 'kosong':
            final setuju = await _konfirmasi(context);
            if (setuju) await kontroler.kosongkanHari();
        }
      },
      itemBuilder: (context) => [
        if (!kontroler.sedangDiHariIni)
          const PopupMenuItem(
            value: 'hari-ini',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.today_outlined),
              title: Text('Kembali ke hari ini'),
            ),
          ),
        const PopupMenuItem(
          value: 'tuntas',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.done_all),
            title: Text('Tandai semua tuntas'),
          ),
        ),
        const PopupMenuItem(
          value: 'kosong',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.backspace_outlined),
            title: Text('Kosongkan catatan hari ini'),
          ),
        ),
      ],
    );
  }

  Future<bool> _konfirmasi(BuildContext context) async {
    final hasil = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kosongkan catatan?'),
        content: Text(
          'Seluruh capaian pada ${formatTanggalPanjang(kontroler.tanggalAktif)} '
          'akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
    return hasil ?? false;
  }
}

/// Kartu ringkasan hari: meter capaian sebagai angka utama.
class _KartuHero extends StatelessWidget {
  const _KartuHero({
    required this.ringkasan,
    required this.streak,
    required this.tanggal,
  });

  final RingkasanHarian ringkasan;
  final int streak;
  final DateTime tanggal;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final tingkat = TingkatPerforma.dariSkor(ringkasan.skor);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppWarna.gradasiHero,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MeterCapaian(
                nilai: ringkasan.skor,
                warna: Colors.white,
                warnaJejak: Colors.white.withValues(alpha: 0.22),
                ukuran: 104,
                ketebalan: 9,
                isi: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${ringkasan.persen}%',
                      style: teks.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'capaian',
                      style: teks.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelRelatif(tanggal),
                      style: teks.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTanggalPanjang(tanggal),
                      style: teks.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${ringkasan.jumlahSelesai} dari '
                      '${ringkasan.jumlahAmalan} amalan tuntas',
                      style: teks.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                LencanaStatus(
                  label: '$streak hari beruntun',
                  warna: Colors.white,
                  ikon: Icons.local_fire_department_outlined,
                  diAtasWarna: true,
                ),
                LencanaStatus(
                  label: tingkat.label,
                  warna: Colors.white,
                  ikon: tingkat.ikon,
                  diAtasWarna: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeksiWaktu extends StatelessWidget {
  const _SeksiWaktu({
    required this.waktu,
    required this.daftar,
    required this.kontroler,
  });

  final WaktuAmalan waktu;
  final List<Amalan> daftar;
  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final tuntas = daftar.where(kontroler.sudahSelesai).length;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(waktu.ikon, size: 17, color: skema.onSurfaceVariant),
                const SizedBox(width: 7),
                Text(
                  waktu.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: VizPalet.jejak(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$tuntas/${daftar.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: skema.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final amalan in daftar) ...[
              KartuAmalan(
                amalan: amalan,
                jumlah: kontroler.capaian(amalan),
                bolehMencatat: kontroler.bolehMencatat,
                jamPengingat: _jamPengingat(kontroler, amalan),
                onKetuk: () => kontroler.ketukAmalan(amalan),
                onKurangi: () => kontroler.kurangiAmalan(amalan),
                onTahan: () => _bukaAksi(context, amalan),
              ),
              const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }

  /// Jam pengingat hari itu, atau null bila amalan ini tanpa pengingat (atau
  /// ditautkan ke sholat tetapi lokasinya belum disetel).
  String? _jamPengingat(AmalanController kontroler, Amalan amalan) {
    if (!amalan.adaPengingat) return null;
    final waktu = kontroler.waktuPengingat(amalan);
    return waktu == null ? null : formatJam(waktu);
  }

  Future<void> _bukaAksi(BuildContext context, Amalan amalan) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                amalan.ikonData,
                color: VizPalet.kategori(context, amalan.kategori),
              ),
              title: Text(
                amalan.nama,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${amalan.kategori.label} · ${amalan.waktu.label}'
                '${amalan.berupaHitungan ? ' · target ${amalan.target} ${amalan.satuan}' : ''}',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Tandai tuntas'),
              enabled: kontroler.bolehMencatat,
              onTap: () {
                Navigator.pop(sheet);
                kontroler.tuntaskanAmalan(amalan);
              },
            ),
            if (amalan.berupaHitungan)
              ListTile(
                leading: const Icon(Icons.dialpad_outlined),
                title: const Text('Atur jumlah'),
                enabled: kontroler.bolehMencatat,
                onTap: () async {
                  Navigator.pop(sheet);
                  await _aturJumlah(context, amalan);
                },
              ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Kosongkan capaian'),
              enabled: kontroler.bolehMencatat,
              onTap: () {
                Navigator.pop(sheet);
                kontroler.setCapaian(amalan, 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Ubah amalan'),
              onTap: () {
                Navigator.pop(sheet);
                bukaFormAmalan(context, amalan: amalan);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aturJumlah(BuildContext context, Amalan amalan) async {
    var nilai = kontroler.capaian(amalan);
    final hasil = await showDialog<int>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, perbarui) => AlertDialog(
          title: Text(amalan.nama),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$nilai / ${amalan.target} ${amalan.satuan}',
                style: Theme.of(dialog).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Slider(
                value: nilai.toDouble(),
                max: amalan.target.toDouble(),
                divisions: amalan.target,
                label: '$nilai',
                onChanged: (v) => perbarui(() => nilai = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, nilai),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (hasil != null) await kontroler.setCapaian(amalan, hasil);
  }
}
