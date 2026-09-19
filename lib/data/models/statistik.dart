import 'package:flutter/material.dart';

import 'amalan.dart';

/// Rekap satu hari: berapa amalan yang dijadwalkan, berapa yang tuntas, dan
/// seberapa besar capaiannya.
@immutable
class RingkasanHarian {
  const RingkasanHarian({
    required this.tanggal,
    required this.jumlahAmalan,
    required this.jumlahSelesai,
    required this.totalTarget,
    required this.totalTercapai,
    required this.jumlahRasio,
  });

  const RingkasanHarian.kosong(this.tanggal)
    : jumlahAmalan = 0,
      jumlahSelesai = 0,
      totalTarget = 0,
      totalTercapai = 0,
      jumlahRasio = 0;

  final DateTime tanggal;

  /// Amalan yang berlaku pada hari ini (belum diarsipkan, sudah dibuat).
  final int jumlahAmalan;
  final int jumlahSelesai;

  /// Jumlah seluruh target hari ini, misalnya 1 + 1 + 100 = 102.
  final int totalTarget;

  /// Total yang benar-benar dikerjakan, dibatasi setinggi target.
  final int totalTercapai;

  /// Penjumlahan capaian tiap amalan, masing-masing bernilai 0..1.
  final double jumlahRasio;

  /// Capaian 0..1, yaitu rata-rata capaian antar-amalan.
  ///
  /// Sengaja bukan `totalTercapai / totalTarget`: dengan rumus itu satu amalan
  /// bertarget 100 akan menenggelamkan sebelas amalan bertarget 1, sehingga
  /// menuntaskan seluruh sholat wajib hanya terbaca beberapa persen. Di sini
  /// tiap amalan berbobot sama, dan capaian sebagian tetap dihargai:
  /// 50 dari 100 istighfar bernilai setengah untuk amalan tersebut.
  double get skor => jumlahAmalan == 0 ? 0 : jumlahRasio / jumlahAmalan;

  int get persen => (skor * 100).round();

  /// Semua amalan hari itu selesai.
  bool get tuntas => jumlahAmalan > 0 && jumlahSelesai == jumlahAmalan;

  bool get adaCatatan => totalTercapai > 0;
}

/// Predikat performa.
///
/// Warnanya memakai palet status (baik/waspada/serius/kritis) yang terpisah dari
/// warna kategori, dan selalu tampil bersama ikon serta label sehingga artinya
/// tidak pernah bergantung pada warna saja.
enum TingkatPerforma {
  istiqomah('Istiqomah', Color(0xFF0CA30C), Icons.verified_outlined),
  baik('Baik', Color(0xFFFAB219), Icons.trending_up),
  cukup('Cukup', Color(0xFFEC835A), Icons.trending_flat),
  perluSemangat('Perlu Semangat', Color(0xFFD03B3B), Icons.trending_down);

  const TingkatPerforma(this.label, this.warna, this.ikon);

  final String label;
  final Color warna;
  final IconData ikon;

  static TingkatPerforma dariSkor(double skor) {
    final persen = skor * 100;
    if (persen >= 85) return istiqomah;
    if (persen >= 70) return baik;
    if (persen >= 50) return cukup;
    return perluSemangat;
  }

  String get saran => switch (this) {
    istiqomah => 'Masya Allah, pertahankan keistiqomahanmu.',
    baik => 'Sudah baik. Kunci amalan yang paling sering terlewat.',
    cukup => 'Mulai dari amalan paling ringan agar kebiasaan terbangun.',
    perluSemangat =>
      'Jangan menyerah. Pilih satu amalan untuk dijaga hari ini.',
  };
}

/// Seberapa sering satu amalan dikerjakan dalam rentang tertentu.
@immutable
class KonsistensiAmalan {
  const KonsistensiAmalan({
    required this.amalan,
    required this.hariBerlaku,
    required this.hariSelesai,
    required this.totalTercapai,
    required this.rataRataCapaian,
  });

  final Amalan amalan;

  /// Berapa hari amalan ini seharusnya dikerjakan dalam rentang.
  final int hariBerlaku;
  final int hariSelesai;

  /// Total satuan yang terkumpul, misalnya 1.250 kali istighfar.
  final int totalTercapai;

  /// Rata-rata capaian harian 0..1, menghargai pencapaian sebagian.
  final double rataRataCapaian;

  double get rasioSelesai => hariBerlaku == 0 ? 0 : hariSelesai / hariBerlaku;

  int get persenSelesai => (rasioSelesai * 100).round();
}

/// Porsi amalan yang tuntas per kategori, untuk grafik lingkaran.
@immutable
class PorsiKategori {
  const PorsiKategori({required this.kategori, required this.jumlahSelesai});

  final KategoriAmalan kategori;
  final int jumlahSelesai;
}

/// Rangkuman performa untuk satu rentang waktu.
@immutable
class PerformaRentang {
  const PerformaRentang({
    required this.harian,
    required this.streakSaatIni,
    required this.streakTerpanjang,
    required this.hariTuntas,
    required this.totalSelesai,
  });

  final List<RingkasanHarian> harian;
  final int streakSaatIni;
  final int streakTerpanjang;
  final int hariTuntas;
  final int totalSelesai;

  double get rataRataSkor {
    if (harian.isEmpty) return 0;
    final total = harian.fold<double>(0, (jml, h) => jml + h.skor);
    return total / harian.length;
  }

  TingkatPerforma get tingkat => TingkatPerforma.dariSkor(rataRataSkor);

  /// Selisih rata-rata paruh terakhir dibanding paruh awal rentang, dipakai
  /// sebagai indikator tren naik atau turun.
  double get perubahan {
    if (harian.length < 4) return 0;
    final tengah = harian.length ~/ 2;
    final awal = harian.take(tengah);
    final akhir = harian.skip(tengah);
    final rataAwal = awal.fold<double>(0, (j, h) => j + h.skor) / awal.length;
    final rataAkhir =
        akhir.fold<double>(0, (j, h) => j + h.skor) / akhir.length;
    return rataAkhir - rataAwal;
  }
}
