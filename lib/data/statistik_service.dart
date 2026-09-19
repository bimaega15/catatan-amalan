import 'dart:math' as math;

import '../core/tanggal.dart';
import 'models/amalan.dart';
import 'models/statistik.dart';

/// Peta catatan: kunci tanggal `yyyy-MM-dd` -> id amalan -> jumlah dikerjakan.
typedef PetaCatatan = Map<String, Map<int, int>>;

/// Batas capaian harian agar sebuah hari dihitung menjaga runtutan (streak).
const double ambangStreak = 0.8;

/// Perhitungan statistik murni, tanpa sentuhan database, supaya mudah diuji.
class StatistikService {
  const StatistikService._();

  /// Amalan yang berlaku pada [tanggal], terurut sesuai preferensi pengguna.
  static List<Amalan> amalanBerlaku(List<Amalan> amalan, DateTime tanggal) {
    final hasil = amalan.where((a) => a.aktifPada(tanggal)).toList()
      ..sort((a, b) {
        final urut = a.urutan.compareTo(b.urutan);
        return urut != 0 ? urut : a.nama.compareTo(b.nama);
      });
    return hasil;
  }

  static RingkasanHarian ringkasanHari(
    List<Amalan> amalan,
    PetaCatatan catatan,
    DateTime tanggal,
  ) {
    final berlaku = amalanBerlaku(amalan, tanggal);
    if (berlaku.isEmpty) return RingkasanHarian.kosong(tglSaja(tanggal));

    final hari = catatan[kunciTanggal(tanggal)] ?? const <int, int>{};
    var selesai = 0;
    var totalTarget = 0;
    var totalTercapai = 0;
    var jumlahRasio = 0.0;

    for (final a in berlaku) {
      final jumlah = hari[a.id] ?? 0;
      final tercapai = math.min(jumlah, a.target);
      totalTarget += a.target;
      totalTercapai += tercapai;
      jumlahRasio += tercapai / a.target;
      if (a.selesaiDengan(jumlah)) selesai++;
    }

    return RingkasanHarian(
      tanggal: tglSaja(tanggal),
      jumlahAmalan: berlaku.length,
      jumlahSelesai: selesai,
      totalTarget: totalTarget,
      totalTercapai: totalTercapai,
      jumlahRasio: jumlahRasio,
    );
  }

  static List<RingkasanHarian> ringkasanRentang(
    List<Amalan> amalan,
    PetaCatatan catatan,
    List<DateTime> hari,
  ) => hari.map((h) => ringkasanHari(amalan, catatan, h)).toList();

  /// Runtutan hari berjalan dengan capaian minimal [ambangStreak].
  ///
  /// Hari ini yang belum tuntas tidak langsung memutus runtutan, karena
  /// harinya memang belum berakhir.
  static int streakSaatIni(
    List<Amalan> amalan,
    PetaCatatan catatan, {
    DateTime? sampai,
    int batasHari = 3650,
  }) {
    final ujung = tglSaja(sampai ?? DateTime.now());
    var streak = 0;

    for (var i = 0; i < batasHari; i++) {
      final hari = ujung.subtract(Duration(days: i));
      final ringkasan = ringkasanHari(amalan, catatan, hari);
      if (ringkasan.jumlahAmalan == 0) break;

      if (ringkasan.skor >= ambangStreak) {
        streak++;
        continue;
      }
      // Hari ini masih berjalan, jadi cukup dilewati tanpa memutus runtutan.
      if (i == 0) continue;
      break;
    }
    return streak;
  }

  /// Runtutan terpanjang di dalam [harian] (urut dari terlama ke terbaru).
  static int streakTerpanjang(List<RingkasanHarian> harian) {
    var terpanjang = 0;
    var berjalan = 0;
    for (final h in harian) {
      if (h.jumlahAmalan > 0 && h.skor >= ambangStreak) {
        berjalan++;
        terpanjang = math.max(terpanjang, berjalan);
      } else {
        berjalan = 0;
      }
    }
    return terpanjang;
  }

  static List<KonsistensiAmalan> konsistensi(
    List<Amalan> amalan,
    PetaCatatan catatan,
    List<DateTime> hari,
  ) {
    final hasil = <KonsistensiAmalan>[];

    for (final a in amalan) {
      var berlaku = 0;
      var selesai = 0;
      var total = 0;
      var akumulasiCapaian = 0.0;

      for (final h in hari) {
        if (!a.aktifPada(h)) continue;
        berlaku++;
        final jumlah = catatan[kunciTanggal(h)]?[a.id] ?? 0;
        total += jumlah;
        akumulasiCapaian += math.min(jumlah, a.target) / a.target;
        if (a.selesaiDengan(jumlah)) selesai++;
      }

      if (berlaku == 0) continue;
      hasil.add(
        KonsistensiAmalan(
          amalan: a,
          hariBerlaku: berlaku,
          hariSelesai: selesai,
          totalTercapai: total,
          rataRataCapaian: akumulasiCapaian / berlaku,
        ),
      );
    }

    hasil.sort((a, b) => b.rasioSelesai.compareTo(a.rasioSelesai));
    return hasil;
  }

  static List<PorsiKategori> porsiKategori(
    List<Amalan> amalan,
    PetaCatatan catatan,
    List<DateTime> hari,
  ) {
    final jumlahPerKategori = <KategoriAmalan, int>{};

    for (final h in hari) {
      final catatanHari = catatan[kunciTanggal(h)];
      if (catatanHari == null || catatanHari.isEmpty) continue;
      for (final a in amalan) {
        if (!a.aktifPada(h)) continue;
        final jumlah = catatanHari[a.id] ?? 0;
        if (!a.selesaiDengan(jumlah)) continue;
        jumlahPerKategori.update(a.kategori, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final hasil =
        jumlahPerKategori.entries
            .map((e) => PorsiKategori(kategori: e.key, jumlahSelesai: e.value))
            .toList()
          ..sort((a, b) => b.jumlahSelesai.compareTo(a.jumlahSelesai));
    return hasil;
  }

  static PerformaRentang performa(
    List<Amalan> amalan,
    PetaCatatan catatan,
    List<DateTime> hari,
  ) {
    final harian = ringkasanRentang(amalan, catatan, hari);
    return PerformaRentang(
      harian: harian,
      streakSaatIni: streakSaatIni(amalan, catatan),
      streakTerpanjang: streakTerpanjang(harian),
      hariTuntas: harian.where((h) => h.tuntas).length,
      totalSelesai: harian.fold<int>(0, (jml, h) => jml + h.jumlahSelesai),
    );
  }
}
