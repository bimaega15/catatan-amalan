import 'package:catatan_amalan/core/tanggal.dart';
import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:catatan_amalan/data/statistik_service.dart';
import 'package:flutter_test/flutter_test.dart';

Amalan _amalan({
  required int id,
  String nama = 'Amalan',
  int target = 1,
  KategoriAmalan kategori = KategoriAmalan.dzikir,
  DateTime? dibuatPada,
  DateTime? diarsipkanPada,
}) {
  return Amalan(
    id: id,
    nama: nama,
    kategori: kategori,
    waktu: WaktuAmalan.bebas,
    target: target,
    dibuatPada: dibuatPada ?? DateTime(2020),
    diarsipkanPada: diarsipkanPada,
  );
}

void main() {
  final ini = hariIni();
  final kemarin = ini.subtract(const Duration(days: 1));

  group('ringkasanHari', () {
    test('amalan bertarget besar tidak menenggelamkan amalan lain', () {
      // Sepuluh amalan bertarget 1 semuanya tuntas, satu amalan bertarget 100
      // belum disentuh. Dengan rumus per satuan, skornya hanya 9%.
      final amalan = [
        for (var i = 1; i <= 10; i++) _amalan(id: i),
        _amalan(id: 11, target: 100),
      ];
      final catatan = {
        kunciTanggal(ini): {for (var i = 1; i <= 10; i++) i: 1},
      };

      final hasil = StatistikService.ringkasanHari(amalan, catatan, ini);

      expect(hasil.jumlahSelesai, 10);
      expect(hasil.persen, 91);
    });

    test('memberi nilai sebagian untuk amalan berupa hitungan', () {
      final amalan = [_amalan(id: 1), _amalan(id: 2, target: 100)];
      final catatan = {
        kunciTanggal(ini): {1: 1, 2: 50},
      };

      final hasil = StatistikService.ringkasanHari(amalan, catatan, ini);

      expect(hasil.jumlahAmalan, 2);
      expect(hasil.jumlahSelesai, 1);
      expect(hasil.totalTarget, 101);
      expect(hasil.totalTercapai, 51);
      // Tiap amalan berbobot sama: (1 + 0,5) / 2, bukan 51 / 101.
      expect(hasil.persen, 75);
      expect(hasil.tuntas, isFalse);
    });

    test('capaian melebihi target tidak dihitung lebih dari target', () {
      final amalan = [_amalan(id: 1, target: 10)];
      final catatan = {
        kunciTanggal(ini): {1: 40},
      };

      final hasil = StatistikService.ringkasanHari(amalan, catatan, ini);

      expect(hasil.totalTercapai, 10);
      expect(hasil.skor, 1);
      expect(hasil.tuntas, isTrue);
    });

    test('amalan yang belum dibuat tidak masuk hitungan hari itu', () {
      final amalan = [_amalan(id: 1, dibuatPada: ini)];

      final hasil = StatistikService.ringkasanHari(amalan, {}, kemarin);

      expect(hasil.jumlahAmalan, 0);
      expect(hasil.skor, 0);
      expect(hasil.tuntas, isFalse);
    });

    test('amalan diarsipkan berhenti dihitung sejak tanggal arsip', () {
      final amalan = [_amalan(id: 1, diarsipkanPada: ini)];

      expect(
        StatistikService.ringkasanHari(amalan, {}, kemarin).jumlahAmalan,
        1,
      );
      expect(StatistikService.ringkasanHari(amalan, {}, ini).jumlahAmalan, 0);
    });
  });

  group('streakSaatIni', () {
    test('menghitung hari berurutan yang mencapai ambang', () {
      final amalan = [_amalan(id: 1)];
      final catatan = {
        for (var i = 0; i < 4; i++)
          kunciTanggal(ini.subtract(Duration(days: i))): {1: 1},
      };

      expect(StatistikService.streakSaatIni(amalan, catatan), 4);
    });

    test('hari ini yang belum tuntas tidak memutus runtutan', () {
      final amalan = [_amalan(id: 1)];
      final catatan = {
        for (var i = 1; i <= 3; i++)
          kunciTanggal(ini.subtract(Duration(days: i))): {1: 1},
      };

      expect(StatistikService.streakSaatIni(amalan, catatan), 3);
    });

    test('hari kosong di tengah memutus runtutan', () {
      final amalan = [_amalan(id: 1)];
      final catatan = {
        kunciTanggal(ini): {1: 1},
        // kemarin sengaja dilewatkan
        kunciTanggal(ini.subtract(const Duration(days: 2))): {1: 1},
      };

      expect(StatistikService.streakSaatIni(amalan, catatan), 1);
    });

    test('berhenti sebelum amalan pertama dibuat', () {
      final amalan = [_amalan(id: 1, dibuatPada: kemarin)];
      final catatan = {
        kunciTanggal(ini): {1: 1},
        kunciTanggal(kemarin): {1: 1},
      };

      expect(StatistikService.streakSaatIni(amalan, catatan), 2);
    });
  });

  test('streakTerpanjang mencari deret terpanjang di dalam rentang', () {
    final amalan = [_amalan(id: 1)];
    final hari = rentangHariTerakhir(6);
    // Pola: tuntas, tuntas, kosong, tuntas, tuntas, tuntas
    final catatan = <String, Map<int, int>>{
      kunciTanggal(hari[0]): {1: 1},
      kunciTanggal(hari[1]): {1: 1},
      kunciTanggal(hari[3]): {1: 1},
      kunciTanggal(hari[4]): {1: 1},
      kunciTanggal(hari[5]): {1: 1},
    };

    final harian = StatistikService.ringkasanRentang(amalan, catatan, hari);

    expect(StatistikService.streakTerpanjang(harian), 3);
  });

  test('konsistensi hanya menghitung hari saat amalan berlaku', () {
    final hari = rentangHariTerakhir(4);
    final amalan = [
      _amalan(id: 1, nama: 'Tilawah', target: 5, dibuatPada: hari[2]),
    ];
    final catatan = {
      kunciTanggal(hari[2]): {1: 5},
      kunciTanggal(hari[3]): {1: 2},
    };

    final hasil = StatistikService.konsistensi(amalan, catatan, hari);

    expect(hasil, hasLength(1));
    expect(hasil.single.hariBerlaku, 2);
    expect(hasil.single.hariSelesai, 1);
    expect(hasil.single.totalTercapai, 7);
    expect(hasil.single.persenSelesai, 50);
    expect(hasil.single.rataRataCapaian, closeTo(0.7, 0.0001));
  });

  test('porsiKategori menghitung amalan tuntas per kategori', () {
    final amalan = [
      _amalan(id: 1, kategori: KategoriAmalan.dzikir),
      _amalan(id: 2, kategori: KategoriAmalan.sholat),
      _amalan(id: 3, kategori: KategoriAmalan.sholat, target: 4),
    ];
    final catatan = {
      kunciTanggal(ini): {1: 1, 2: 1, 3: 2},
      kunciTanggal(kemarin): {2: 1},
    };

    final hasil = StatistikService.porsiKategori(amalan, catatan, [
      kemarin,
      ini,
    ]);

    // Sholat tuntas dua kali; amalan id 3 belum memenuhi target jadi diabaikan.
    expect(hasil.first.kategori, KategoriAmalan.sholat);
    expect(hasil.first.jumlahSelesai, 2);
    expect(
      hasil
          .firstWhere((p) => p.kategori == KategoriAmalan.dzikir)
          .jumlahSelesai,
      1,
    );
  });

  test('performa merangkum rata-rata, hari tuntas, dan tren', () {
    final amalan = [_amalan(id: 1)];
    final hari = rentangHariTerakhir(4);
    final catatan = {
      // Paruh awal kosong, paruh akhir tuntas: tren naik.
      kunciTanggal(hari[2]): {1: 1},
      kunciTanggal(hari[3]): {1: 1},
    };

    final hasil = StatistikService.performa(amalan, catatan, hari);

    expect(hasil.harian, hasLength(4));
    expect(hasil.rataRataSkor, closeTo(0.5, 0.0001));
    expect(hasil.hariTuntas, 2);
    expect(hasil.totalSelesai, 2);
    expect(hasil.perubahan, closeTo(1.0, 0.0001));
  });
}
