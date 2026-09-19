import 'package:flutter/material.dart';

import '../data/wilayah_indonesia.dart';

/// Pemilih wilayah acuan jadwal sholat.
///
/// Ada supaya jadwal bisa muncul tanpa GPS dan tanpa internet: pengguna cukup
/// memilih kota terdekat. Mengembalikan [Wilayah] terpilih, atau null bila
/// ditutup tanpa memilih.
class PilihWilayahScreen extends StatefulWidget {
  const PilihWilayahScreen({super.key, this.terpilih});

  /// Label wilayah yang sedang dipakai, untuk ditandai di daftar.
  final String? terpilih;

  @override
  State<PilihWilayahScreen> createState() => _PilihWilayahScreenState();
}

class _PilihWilayahScreenState extends State<PilihWilayahScreen> {
  final _pencarian = TextEditingController();
  List<Wilayah> _hasil = wilayahIndonesia;

  @override
  void dispose() {
    _pencarian.dispose();
    super.dispose();
  }

  void _cari(String kata) => setState(() => _hasil = cariWilayah(kata));

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih wilayah')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _pencarian,
              autofocus: true,
              onChanged: _cari,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari kota atau provinsi',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pencarian.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _pencarian.clear();
                          _cari('');
                        },
                      ),
              ),
            ),
          ),
          if (_hasil.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Kota "${_pencarian.text}" belum ada di daftar. Pilih kota '
                    'terdekat, atau pakai deteksi lokasi agar persis.',
                    textAlign: TextAlign.center,
                    style: teks.bodyMedium?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _hasil.length,
                itemBuilder: (context, indeks) {
                  final wilayah = _hasil[indeks];
                  final aktif = wilayah.label == widget.terpilih;
                  // Nama provinsi hanya ditulis sekali di awal kelompoknya.
                  final kepala =
                      indeks == 0 ||
                      _hasil[indeks - 1].provinsi != wilayah.provinsi;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kepala)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                          child: Text(
                            wilayah.provinsi.toUpperCase(),
                            style: teks.labelSmall?.copyWith(
                              color: skema.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ListTile(
                        leading: Icon(
                          aktif
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: aktif ? skema.primary : skema.onSurfaceVariant,
                        ),
                        title: Text(wilayah.nama),
                        onTap: () => Navigator.pop(context, wilayah),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
