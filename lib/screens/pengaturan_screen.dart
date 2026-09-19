import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/amalan.dart';
import '../data/models/pengaturan.dart';
import '../services/berkas_service.dart';
import '../services/jadwal_sholat_service.dart';
import '../state/amalan_controller.dart';
import '../widgets/umum.dart';

/// Lokasi & jadwal sholat, pengingat, serta ekspor/impor data.
class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kontroler = context.watch<AmalanController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SeksiLokasi(kontroler: kontroler),
          const SizedBox(height: 14),
          _SeksiJadwal(kontroler: kontroler),
          const SizedBox(height: 14),
          _SeksiNotifikasi(kontroler: kontroler),
          const SizedBox(height: 14),
          _SeksiData(kontroler: kontroler),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- lokasi

class _SeksiLokasi extends StatelessWidget {
  const _SeksiLokasi({required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final pengaturan = kontroler.pengaturan;

    return KartuPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JudulSeksi(
            judul: 'Lokasi',
            keterangan: 'Dipakai menghitung jadwal sholat harian',
          ),
          const SizedBox(height: 14),
          if (pengaturan.adaLokasi) ...[
            Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: skema.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pengaturan.labelLokasi ?? '—',
                    style: teks.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (pengaturan.lokasiDiperbaruiPada != null) ...[
              const SizedBox(height: 4),
              Text(
                'Diperbarui '
                '${formatTanggalPendek(pengaturan.lokasiDiperbaruiPada!)}',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
            ],
          ] else
            Text(
              'Lokasi belum disetel. Tanpa lokasi, jadwal sholat tidak bisa '
              'dihitung dan amalan sholat wajib tidak akan mengirim pengingat.',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: kontroler.sedangAmbilLokasi
                      ? null
                      : () => _ambilLokasi(context),
                  icon: kontroler.sedangAmbilLokasi
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    pengaturan.adaLokasi
                        ? 'Perbarui lokasi'
                        : 'Deteksi lokasi saya',
                  ),
                ),
              ),
              if (pengaturan.adaLokasi) ...[
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Hapus lokasi',
                  onPressed: kontroler.hapusLokasi,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _ambilLokasi(BuildContext context) async {
    final pesan = ScaffoldMessenger.of(context);
    try {
      await kontroler.perbaruiLokasi();
      pesan.showSnackBar(
        const SnackBar(content: Text('Jadwal sholat diperbarui.')),
      );
    } on LokasiException catch (e) {
      pesan.showSnackBar(SnackBar(content: Text(e.pesan)));
    } catch (e) {
      pesan.showSnackBar(SnackBar(content: Text('Gagal mengambil lokasi: $e')));
    }
  }
}

// ------------------------------------------------------------------- jadwal

class _SeksiJadwal extends StatelessWidget {
  const _SeksiJadwal({required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final jadwal = kontroler.jadwalSholat(hariIni());
    final pengaturan = kontroler.pengaturan;

    return KartuPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JudulSeksi(
            judul: 'Jadwal sholat',
            keterangan: formatTanggalPanjang(hariIni()),
          ),
          const SizedBox(height: 14),
          if (jadwal == null)
            Text(
              'Setel lokasi lebih dulu untuk melihat jadwalnya.',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            )
          else
            for (final sholat in SholatWajib.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.mosque_outlined,
                      size: 16,
                      color: VizPalet.kategori(context, KategoriAmalan.sholat),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(sholat.label)),
                    Text(
                      jadwal[sholat] == null ? '—' : formatJam(jadwal[sholat]!),
                      style: teks.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            'Metode perhitungan',
            style: teks.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<MetodeSholat>(
            initialValue: pengaturan.metode,
            isExpanded: true,
            items: [
              for (final metode in MetodeSholat.values)
                DropdownMenuItem(
                  value: metode,
                  child: Text(
                    '${metode.label} — ${metode.keterangan}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (nilai) {
              if (nilai != null) kontroler.pilihMetodeSholat(nilai);
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Mazhab penentu Ashar',
            style: teks.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final mazhab in MazhabAshar.values)
                ChoiceChip(
                  label: Text(mazhab.label),
                  selected: pengaturan.mazhab == mazhab,
                  onSelected: (_) => kontroler.pilihMazhab(mazhab),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- notifikasi

class _SeksiNotifikasi extends StatelessWidget {
  const _SeksiNotifikasi({required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final berpengingat = kontroler.amalanAktif
        .where((a) => a.adaPengingat)
        .length;

    return KartuPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JudulSeksi(
            judul: 'Pengingat',
            keterangan: 'Bunyi tiga bip pendek pada jam yang disetel',
          ),
          const SizedBox(height: 6),
          if (!kontroler.notifikasiDidukung)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Notifikasi hanya berjalan di Android dan iOS.',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
            )
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: kontroler.pengaturan.notifikasiAktif,
              onChanged: kontroler.setNotifikasi,
              title: const Text('Aktifkan pengingat'),
              subtitle: Text('$berpengingat amalan punya jam pengingat'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: kontroler.ujiBunyiNotifikasi,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Coba bunyinya'),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- data

class _SeksiData extends StatefulWidget {
  const _SeksiData({required this.kontroler});

  final AmalanController kontroler;

  @override
  State<_SeksiData> createState() => _SeksiDataState();
}

class _SeksiDataState extends State<_SeksiData> {
  bool _sibuk = false;

  AmalanController get _kontroler => widget.kontroler;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return KartuPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JudulSeksi(
            judul: 'Data',
            keterangan: 'Semua data tersimpan di perangkat ini saja',
          ),
          const SizedBox(height: 14),
          _Tombol(
            ikon: Icons.table_chart_outlined,
            judul: 'Ekspor ke Excel',
            keterangan: 'Daftar amalan, catatan harian, dan rekap',
            aktif: !_sibuk,
            onTekan: _eksporExcel,
          ),
          const SizedBox(height: 10),
          _Tombol(
            ikon: Icons.storage_outlined,
            judul: 'Ekspor seluruh data (SQL)',
            keterangan: 'Cadangan lengkap untuk dipulihkan lagi',
            aktif: !_sibuk,
            onTekan: _eksporSql,
          ),
          const SizedBox(height: 10),
          _Tombol(
            ikon: Icons.restore_outlined,
            judul: 'Impor dari berkas SQL',
            keterangan: 'Mengganti seluruh data yang ada sekarang',
            aktif: !_sibuk,
            onTekan: _imporSql,
          ),
          const SizedBox(height: 12),
          Text(
            'Impor akan menimpa seluruh catatan di perangkat ini. Sebaiknya '
            'ekspor dulu sebelum mengimpor.',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _jalankan(Future<String> Function() aksi) async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    final pesan = ScaffoldMessenger.of(context);
    try {
      pesan.showSnackBar(SnackBar(content: Text(await aksi())));
    } catch (e) {
      pesan.showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _eksporExcel() => _jalankan(() async {
    final hasil = await BerkasService.simpanBiner(
      namaBerkas: BerkasService.namaBercapWaktu('catatan-amalan', 'xlsx'),
      isi: _kontroler.susunExcel(),
      jenisMime:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      labelJenis: 'Excel',
      ekstensi: 'xlsx',
    );
    return hasil.pesan;
  });

  Future<void> _eksporSql() => _jalankan(() async {
    final hasil = await BerkasService.simpanTeks(
      namaBerkas: BerkasService.namaBercapWaktu('catatan-amalan', 'sql'),
      isi: await _kontroler.susunSql(),
      jenisMime: 'application/sql',
      labelJenis: 'SQL',
      ekstensi: 'sql',
    );
    return hasil.pesan;
  });

  Future<void> _imporSql() async {
    final berkas = await BerkasService.bukaTeks(
      labelJenis: 'Cadangan SQL',
      ekstensi: const ['sql', 'txt'],
    );
    if (berkas == null || !mounted) return;

    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Impor data?'),
        content: Text(
          'Seluruh amalan dan catatan di perangkat ini akan diganti dengan isi '
          '"${berkas.nama}". Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Impor'),
          ),
        ],
      ),
    );
    if (setuju != true) return;

    await _jalankan(() async {
      final jumlah = await _kontroler.pulihkanDariSql(berkas.isi);
      return '$jumlah baris dipulihkan dari ${berkas.nama}.';
    });
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.aktif,
    required this.onTekan,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final bool aktif;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Opacity(
      opacity: aktif ? 1 : 0.5,
      child: Material(
        color: VizPalet.jejak(context),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aktif ? onTekan : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(ikon, size: 20, color: skema.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judul,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        keterangan,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: skema.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
