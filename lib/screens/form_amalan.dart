import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/ikon_amalan.dart';
import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/amalan.dart';
import '../state/amalan_controller.dart';

/// Membuka lembar tambah/ubah amalan. Mengembalikan `true` bila tersimpan.
Future<bool> bukaFormAmalan(BuildContext context, {Amalan? amalan}) async {
  final hasil = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => FormAmalan(amalan: amalan),
  );
  return hasil ?? false;
}

/// Formulir satu amalan: nama, kategori, waktu, target, ikon, catatan.
class FormAmalan extends StatefulWidget {
  const FormAmalan({super.key, this.amalan});

  final Amalan? amalan;

  @override
  State<FormAmalan> createState() => _FormAmalanState();
}

class _FormAmalanState extends State<FormAmalan> {
  final _kunciForm = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _catatan;
  late final TextEditingController _target;

  late KategoriAmalan _kategori;
  late WaktuAmalan _waktu;
  late String _satuan;
  late String _ikon;
  late bool _pakaiHitungan;

  bool get _ubah => widget.amalan != null;

  @override
  void initState() {
    super.initState();
    final awal = widget.amalan;
    _nama = TextEditingController(text: awal?.nama ?? '');
    _catatan = TextEditingController(text: awal?.catatan ?? '');
    _pakaiHitungan = (awal?.target ?? 1) > 1;
    _target = TextEditingController(
      text: _pakaiHitungan ? '${awal!.target}' : '33',
    );
    _kategori = awal?.kategori ?? KategoriAmalan.dzikir;
    _waktu = awal?.waktu ?? WaktuAmalan.bebas;
    _satuan = awal?.satuan ?? satuanAmalan.first;
    _ikon = awal?.ikon ?? ikonBawaan;
  }

  @override
  void dispose() {
    _nama.dispose();
    _catatan.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!(_kunciForm.currentState?.validate() ?? false)) return;

    final kontroler = context.read<AmalanController>();
    final navigator = Navigator.of(context);
    final pesan = ScaffoldMessenger.of(context);

    final target = _pakaiHitungan
        ? (int.tryParse(_target.text.trim()) ?? 1)
        : 1;
    final catatan = _catatan.text.trim();

    final data =
        (widget.amalan ??
                Amalan(
                  nama: '',
                  kategori: _kategori,
                  waktu: _waktu,
                  dibuatPada: hariIni(),
                ))
            .copyWith(
              nama: _nama.text.trim(),
              catatan: catatan.isEmpty ? null : catatan,
              hapusCatatan: catatan.isEmpty,
              kategori: _kategori,
              waktu: _waktu,
              target: target < 1 ? 1 : target,
              satuan: _satuan,
              ikon: _ikon,
            );

    if (_ubah) {
      await kontroler.perbaruiAmalan(data);
    } else {
      await kontroler.tambahAmalan(data);
    }

    navigator.pop(true);
    pesan.showSnackBar(
      SnackBar(
        content: Text(_ubah ? 'Amalan diperbarui.' : 'Amalan ditambahkan.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _kunciForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ubah ? 'Ubah amalan' : 'Amalan baru',
                style: teks.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Catatan ini tersimpan di perangkatmu sendiri.',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama amalan',
                  hintText: 'Misalnya: Dzikir Pagi',
                ),
                validator: (nilai) => (nilai == null || nilai.trim().isEmpty)
                    ? 'Nama amalan belum diisi'
                    : null,
              ),
              const SizedBox(height: 22),
              const _Label('Kategori'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kategori in KategoriAmalan.values)
                    ChoiceChip(
                      label: Text(kategori.label),
                      selected: _kategori == kategori,
                      avatar: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: VizPalet.kategori(context, kategori),
                          shape: BoxShape.circle,
                        ),
                      ),
                      onSelected: (_) => setState(() => _kategori = kategori),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              const _Label('Waktu pengerjaan'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final waktu in WaktuAmalan.values)
                    ChoiceChip(
                      label: Text(waktu.label),
                      avatar: Icon(waktu.ikon, size: 16),
                      selected: _waktu == waktu,
                      onSelected: (_) => setState(() => _waktu = waktu),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SwitchListTile(
                value: _pakaiHitungan,
                onChanged: (nilai) => setState(() => _pakaiHitungan = nilai),
                contentPadding: EdgeInsets.zero,
                title: const Text('Pakai target hitungan'),
                subtitle: const Text(
                  'Untuk amalan berjumlah, misalnya istighfar 100 kali '
                  'atau tilawah 5 halaman.',
                ),
              ),
              if (_pakaiHitungan) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _target,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: 'Target'),
                        validator: (nilai) {
                          final angka = int.tryParse(nilai?.trim() ?? '');
                          if (angka == null || angka < 2) {
                            return 'Minimal 2';
                          }
                          if (angka > 10000) return 'Terlalu besar';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _satuan,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: [
                          for (final satuan in satuanAmalan)
                            DropdownMenuItem(
                              value: satuan,
                              child: Text(satuan),
                            ),
                        ],
                        onChanged: (nilai) => setState(
                          () => _satuan = nilai ?? satuanAmalan.first,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              const _Label('Ikon'),
              const SizedBox(height: 10),
              _PemilihIkon(
                terpilih: _ikon,
                warna: VizPalet.kategori(context, _kategori),
                onPilih: (kunci) => setState(() => _ikon = kunci),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _catatan,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Pengingat kecil untuk dirimu sendiri',
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _simpan,
                icon: const Icon(Icons.check),
                label: Text(_ubah ? 'Simpan perubahan' : 'Tambahkan amalan'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Text(
    teks,
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _PemilihIkon extends StatelessWidget {
  const _PemilihIkon({
    required this.terpilih,
    required this.warna,
    required this.onPilih,
  });

  final String terpilih;
  final Color warna;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final kunci = katalogIkonAmalan.keys.toList();

    return SizedBox(
      height: 104,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: kunci.length,
        itemBuilder: (context, indeks) {
          final nama = kunci[indeks];
          final aktif = nama == terpilih;
          return Material(
            color: aktif
                ? warna.withValues(alpha: 0.16)
                : VizPalet.jejak(context),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onPilih(nama),
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: aktif ? Border.all(color: warna, width: 1.8) : null,
                ),
                child: Icon(
                  katalogIkonAmalan[nama],
                  size: 22,
                  color: aktif ? warna : skema.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
