import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/ikon_amalan.dart';
import '../core/tanggal.dart';
import '../core/viz_palette.dart';
import '../data/models/amalan.dart';
import '../services/jadwal_sholat_service.dart';
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
  late SholatWajib? _sholat;
  late int? _menitPengingat;

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
    _sholat = awal?.sholat;
    _menitPengingat = awal?.menitPengingat;
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
              sholat: _sholat,
              hapusSholat: _sholat == null,
              menitPengingat: _sholat == null ? _menitPengingat : null,
              hapusPengingat: _sholat != null || _menitPengingat == null,
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
              const _Label('Pengingat'),
              const SizedBox(height: 8),
              _PengaturPengingat(
                kategori: _kategori,
                sholat: _sholat,
                menit: _menitPengingat,
                onSholat: (nilai) => setState(() {
                  _sholat = nilai;
                  if (nilai != null) _menitPengingat = null;
                }),
                onMenit: (nilai) => setState(() {
                  _menitPengingat = nilai;
                  if (nilai != null) _sholat = null;
                }),
              ),
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

/// Pengatur jam pengingat.
///
/// Dua pilihan yang saling meniadakan: mengikuti jadwal sholat harian (jamnya
/// bergeser tiap hari mengikuti lokasi) atau jam tetap. Keduanya boleh kosong
/// bila amalan ini tidak perlu diingatkan.
class _PengaturPengingat extends StatelessWidget {
  const _PengaturPengingat({
    required this.kategori,
    required this.sholat,
    required this.menit,
    required this.onSholat,
    required this.onMenit,
  });

  final KategoriAmalan kategori;
  final SholatWajib? sholat;
  final int? menit;
  final ValueChanged<SholatWajib?> onSholat;
  final ValueChanged<int?> onMenit;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final kontroler = context.watch<AmalanController>();
    final jadwal = kontroler.jadwalSholat(hariIni());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tanpa pengingat'),
              selected: sholat == null && menit == null,
              onSelected: (_) {
                onSholat(null);
                onMenit(null);
              },
            ),
            ChoiceChip(
              label: Text(
                menit == null ? 'Jam tetap' : 'Jam ${formatMenit(menit!)}',
              ),
              avatar: const Icon(Icons.schedule_outlined, size: 16),
              selected: menit != null,
              onSelected: (_) => _pilihJam(context),
            ),
            ChoiceChip(
              label: Text(
                sholat == null
                    ? 'Ikut jadwal sholat'
                    : 'Jadwal ${sholat!.label}',
              ),
              avatar: const Icon(Icons.mosque_outlined, size: 16),
              selected: sholat != null,
              onSelected: (_) => _pilihSholat(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _keterangan(jadwal),
          style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
      ],
    );
  }

  String _keterangan(JadwalSholat? jadwal) {
    final pilihan = sholat;
    if (pilihan != null) {
      final jam = jadwal?[pilihan];
      return jam == null
          ? 'Jamnya mengikuti jadwal sholat harian. Setel lokasi di '
                'Pengaturan agar jadwalnya terhitung.'
          : 'Hari ini ${pilihan.label} pukul ${formatJam(jam)}, '
                'dan akan bergeser sendiri tiap hari.';
    }
    if (menit != null) {
      return 'Diingatkan tiap hari pukul ${formatMenit(menit!)}.';
    }
    return 'Amalan ini tidak akan mengirim notifikasi.';
  }

  Future<void> _pilihJam(BuildContext context) async {
    final awal = menit ?? _jamUsulan();
    final pilihan = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: awal ~/ 60, minute: awal % 60),
      helpText: 'Jam pengingat',
    );
    if (pilihan != null) onMenit(pilihan.hour * 60 + pilihan.minute);
  }

  /// Usulan jam awal yang masuk akal menurut kategori amalan.
  int _jamUsulan() => switch (kategori) {
    KategoriAmalan.quran => 5 * 60,
    KategoriAmalan.dzikir => 6 * 60,
    KategoriAmalan.sunnah => 4 * 60 + 30,
    _ => 20 * 60,
  };

  Future<void> _pilihSholat(BuildContext context) async {
    final jadwal = context.read<AmalanController>().jadwalSholat(hariIni());
    final pilihan = await showModalBottomSheet<SholatWajib>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Ikut jadwal sholat',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Jam pengingat dihitung ulang tiap hari dari lokasimu.',
              ),
            ),
            const Divider(),
            for (final s in SholatWajib.values)
              ListTile(
                leading: const Icon(Icons.mosque_outlined),
                title: Text(s.label),
                trailing: Text(
                  jadwal?[s] == null ? '—' : formatJam(jadwal![s]!),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(sheet, s),
              ),
          ],
        ),
      ),
    );
    if (pilihan != null) onSholat(pilihan);
  }
}
