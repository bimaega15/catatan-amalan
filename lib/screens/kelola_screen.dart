import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/amalan.dart';
import '../state/amalan_controller.dart';
import '../widgets/umum.dart';
import 'form_amalan.dart';

/// Pengelolaan daftar amalan: menambah, mengubah, mengurutkan, mengarsipkan.
class KelolaScreen extends StatelessWidget {
  const KelolaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kontroler = context.watch<AmalanController>();
    final aktif = kontroler.amalanAktif;
    final arsip = kontroler.amalanDiarsipkan;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => bukaFormAmalan(context),
        icon: const Icon(Icons.add),
        label: const Text('Amalan'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Daftar Amalan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
              child: Text(
                'Tahan dan geser untuk mengubah urutan tampilan.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (aktif.isEmpty)
              KeadaanKosong(
                ikon: Icons.tune_outlined,
                judul: 'Daftar masih kosong',
                pesan: 'Buat amalan pertamamu untuk mulai dicatat setiap hari.',
                aksi: FilledButton.icon(
                  onPressed: () => bukaFormAmalan(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah amalan'),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: aktif.length,
                onReorder: kontroler.pindahkanAmalan,
                itemBuilder: (context, indeks) {
                  final amalan = aktif[indeks];
                  return Padding(
                    key: ValueKey(amalan.id ?? amalan.nama),
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _BarisAmalan(
                      amalan: amalan,
                      indeks: indeks,
                      kontroler: kontroler,
                    ),
                  );
                },
              ),
            if (arsip.isNotEmpty) ...[
              const SizedBox(height: 26),
              const JudulSeksi(
                judul: 'Diarsipkan',
                keterangan: 'Tidak lagi dihitung, riwayat lama tetap tersimpan',
              ),
              const SizedBox(height: 12),
              for (final amalan in arsip) ...[
                _BarisArsip(amalan: amalan, kontroler: kontroler),
                const SizedBox(height: 9),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BarisAmalan extends StatelessWidget {
  const _BarisAmalan({
    required this.amalan,
    required this.indeks,
    required this.kontroler,
  });

  final Amalan amalan;
  final int indeks;
  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final warna = VizPalet.kategori(context, amalan.kategori);

    return KartuPanel(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: indeks,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: skema.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(amalan.ikonData, size: 19, color: warna),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amalan.nama,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    amalan.kategori.label,
                    amalan.waktu.label,
                    if (amalan.berupaHitungan)
                      '${amalan.target} ${amalan.satuan}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (nilai) async {
              switch (nilai) {
                case 'ubah':
                  await bukaFormAmalan(context, amalan: amalan);
                case 'arsip':
                  await kontroler.arsipkanAmalan(amalan);
                case 'hapus':
                  await _konfirmasiHapus(context, kontroler, amalan);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'ubah',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Ubah'),
                ),
              ),
              PopupMenuItem(
                value: 'arsip',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Arsipkan'),
                ),
              ),
              PopupMenuItem(
                value: 'hapus',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Hapus'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarisArsip extends StatelessWidget {
  const _BarisArsip({required this.amalan, required this.kontroler});

  final Amalan amalan;
  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return KartuPanel(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Icon(amalan.ikonData, size: 19, color: skema.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amalan.nama,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: skema.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Diarsipkan ${formatTanggalPendek(amalan.diarsipkanPada!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Aktifkan kembali',
            onPressed: () => kontroler.aktifkanAmalan(amalan),
            icon: const Icon(Icons.unarchive_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Hapus permanen',
            onPressed: () => _konfirmasiHapus(context, kontroler, amalan),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

Future<void> _konfirmasiHapus(
  BuildContext context,
  AmalanController kontroler,
  Amalan amalan,
) async {
  final pesan = ScaffoldMessenger.of(context);
  final setuju = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('Hapus "${amalan.nama}"?'),
      content: const Text(
        'Seluruh riwayat amalan ini juga akan terhapus dan tidak bisa '
        'dikembalikan. Untuk berhenti mencatatnya tanpa kehilangan riwayat, '
        'pilih Arsipkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialog).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );

  if (setuju != true) return;
  await kontroler.hapusAmalan(amalan);
  pesan.showSnackBar(SnackBar(content: Text('"${amalan.nama}" dihapus.')));
}
