import 'package:flutter/material.dart';

import '../data/models/amalan.dart';

/// Palet khusus grafik.
///
/// Warna di sini bukan selera: urutannya sudah diuji agar tiap pasangan
/// bersebelahan tetap terbedakan oleh mata normal maupun buta warna
/// (protan/deutan/tritan), dan tiap warna cukup kontras terhadap permukaan
/// kartu terang (#FFFFFF) maupun gelap (#1B2226). Jangan menyisipkan,
/// menukar, atau memutar ulang slot tanpa memvalidasi kembali.
class VizPalet {
  const VizPalet._();

  /// Slot kategori untuk mode terang, sesuai urutan [KategoriAmalan].
  static const List<Color> _kategoriTerang = [
    Color(0xFF2A78D6), // biru    - dzikir
    Color(0xFFEB6834), // jingga  - sholat
    Color(0xFF1BAF7A), // akua    - quran
    Color(0xFFEDA100), // kuning  - sunnah
    Color(0xFFE87BA4), // magenta - sosial
    Color(0xFF008300), // hijau   - lainnya
  ];

  /// Slot yang sama, dilangkahkan ulang untuk permukaan gelap.
  static const List<Color> _kategoriGelap = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
  ];

  /// Tangga satu warna untuk besaran (kalender riwayat). Makin tinggi capaian,
  /// makin gelap di mode terang dan makin terang di mode gelap.
  static const List<Color> _tanggaTerang = [
    Color(0xFFD3EBE2),
    Color(0xFFA2D8C6),
    Color(0xFF6CC0A6),
    Color(0xFF2F9E7D),
    Color(0xFF0E7A5E),
  ];

  static const List<Color> _tanggaGelap = [
    Color(0xFF1E3B33),
    Color(0xFF245B4B),
    Color(0xFF2C8068),
    Color(0xFF38A886),
    Color(0xFF52C9A5),
  ];

  static const Color _kosongTerang = Color(0xFFEDEFEE);
  static const Color _kosongGelap = Color(0xFF242B2F);

  static bool _gelap(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Warna identitas satu kategori. Warna mengikuti kategorinya, bukan
  /// peringkatnya, sehingga penyaringan tidak pernah mengubah warna yang lolos.
  static Color kategori(BuildContext context, KategoriAmalan kategori) {
    final daftar = _gelap(context) ? _kategoriGelap : _kategoriTerang;
    return daftar[kategori.index % daftar.length];
  }

  static List<Color> tangga(BuildContext context) =>
      _gelap(context) ? _tanggaGelap : _tanggaTerang;

  static Color kosong(BuildContext context) =>
      _gelap(context) ? _kosongGelap : _kosongTerang;

  /// Warna sel kalender untuk capaian 0..1.
  static Color selCapaian(
    BuildContext context,
    double skor, {
    bool adaCatatan = true,
  }) {
    if (!adaCatatan || skor <= 0) return kosong(context);
    final daftar = tangga(context);
    final indeks = (skor * daftar.length).ceil().clamp(1, daftar.length) - 1;
    return daftar[indeks];
  }

  /// Warna tulisan yang tetap terbaca di atas [latar].
  static Color tintaDiAtas(Color latar) =>
      latar.computeLuminance() > 0.45 ? const Color(0xFF12171A) : Colors.white;

  /// Garis kisi setipis mungkin agar tidak bersaing dengan data.
  static Color kisi(BuildContext context) =>
      _gelap(context) ? const Color(0xFF2C3237) : const Color(0xFFE6E9E8);

  static Color sumbu(BuildContext context) =>
      _gelap(context) ? const Color(0xFF3A4247) : const Color(0xFFC9CFCD);

  /// Tinta label sumbu: selalu warna teks, tidak pernah warna seri.
  static Color tintaRedup(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Jejak (track) di belakang meter dan bilah, senada tapi mengalah.
  static Color jejak(BuildContext context) =>
      _gelap(context) ? const Color(0xFF283034) : const Color(0xFFEBEFED);
}
