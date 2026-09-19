import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/tanggal.dart';
import '../data/models/amalan.dart';
import '../data/models/pengaturan.dart';

/// Waktu lima sholat fardhu untuk satu hari di satu lokasi.
@immutable
class JadwalSholat {
  const JadwalSholat({
    required this.tanggal,
    required this.waktu,
    this.resmi = false,
  });

  final DateTime tanggal;
  final Map<SholatWajib, DateTime> waktu;

  /// Diambil dari API resmi, bukan dihitung di perangkat.
  final bool resmi;

  DateTime? operator [](SholatWajib sholat) => waktu[sholat];

  /// Sholat berikutnya setelah [acuan] pada hari yang sama, bila masih ada.
  MapEntry<SholatWajib, DateTime>? berikutnya(DateTime acuan) {
    for (final sholat in SholatWajib.values) {
      final jam = waktu[sholat];
      if (jam != null && jam.isAfter(acuan)) return MapEntry(sholat, jam);
    }
    return null;
  }
}

/// Alasan gagalnya pengambilan lokasi, supaya UI bisa menjelaskan langkah
/// perbaikannya alih-alih sekadar bilang "gagal".
enum GalatLokasi {
  layananMati('Layanan lokasi perangkat sedang mati. Nyalakan lebih dulu.'),
  izinDitolak('Izin lokasi ditolak. Berikan izin untuk menghitung jadwal.'),
  izinDitolakPermanen(
    'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan sistem.',
  ),
  tidakDidukung('Perangkat ini tidak menyediakan data lokasi.'),
  gagal('Lokasi tidak bisa diambil. Coba lagi beberapa saat lagi.');

  const GalatLokasi(this.pesan);

  final String pesan;
}

/// Dilempar saat lokasi tidak bisa diambil; pesannya sudah siap ditampilkan.
class LokasiException implements Exception {
  const LokasiException(this.jenis);

  final GalatLokasi jenis;

  String get pesan => jenis.pesan;

  @override
  String toString() => 'LokasiException(${jenis.name}): $pesan';
}

/// Menghitung jadwal sholat dan mengambil koordinat perangkat.
///
/// Jadwal sengaja tidak disimpan ke database: perhitungannya murni dan cepat,
/// jadi lebih baik dihitung ulang per hari daripada menyimpan data yang bisa
/// basi saat pengguna berpindah kota.
class JadwalSholatService {
  const JadwalSholatService._();

  /// Menghitung jadwal untuk [tanggal]. Mengembalikan null bila lokasi belum
  /// pernah diambil.
  static JadwalSholat? hitung(Pengaturan pengaturan, DateTime tanggal) {
    final lintang = pengaturan.lintang;
    final bujur = pengaturan.bujur;
    if (lintang == null || bujur == null) return null;

    final metode = pengaturan.metode;
    final parameter = CalculationParameters(
      fajrAngle: metode.sudutSubuh,
      ishaAngle: metode.sudutIsya,
      ishaInterval: metode.jedaIsyaMenit,
      madhab: pengaturan.mazhab == MazhabAshar.hanafi
          ? Madhab.hanafi
          : Madhab.shafi,
    );

    final hari = tglSaja(tanggal);
    final waktu = PrayerTimes(
      Coordinates(lintang, bujur),
      DateComponents.from(hari),
      parameter,
    );

    return JadwalSholat(
      tanggal: hari,
      waktu: {
        SholatWajib.subuh: waktu.fajr,
        SholatWajib.dzuhur: waktu.dhuhr,
        SholatWajib.ashar: waktu.asr,
        SholatWajib.maghrib: waktu.maghrib,
        SholatWajib.isya: waktu.isha,
      },
      resmi: false,
    );
  }

  /// Jam pengingat efektif sebuah amalan pada [tanggal].
  ///
  /// Amalan yang ditautkan ke sholat mengikuti jadwal hari itu; sisanya
  /// memakai jam tetap yang disetel pengguna.
  static DateTime? waktuPengingat(
    Amalan amalan,
    DateTime tanggal, {
    JadwalSholat? jadwal,
  }) {
    final sholat = amalan.sholat;
    if (sholat != null) return jadwal?[sholat];

    final menit = amalan.menitPengingat;
    if (menit == null) return null;
    final hari = tglSaja(tanggal);
    return DateTime(hari.year, hari.month, hari.day, menit ~/ 60, menit % 60);
  }

  /// Mengambil koordinat perangkat, lengkap dengan urusan izinnya.
  static Future<Position> ambilLokasi() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LokasiException(GalatLokasi.layananMati);
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.deniedForever) {
      throw const LokasiException(GalatLokasi.izinDitolakPermanen);
    }
    if (izin == LocationPermission.denied) {
      throw const LokasiException(GalatLokasi.izinDitolak);
    }
    if (izin == LocationPermission.unableToDetermine) {
      throw const LokasiException(GalatLokasi.tidakDidukung);
    }

    try {
      // Ketelitian sedang sudah lebih dari cukup: selisih beberapa ratus meter
      // hanya menggeser waktu sholat dalam hitungan detik.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on LokasiException {
      rethrow;
    } catch (_) {
      final terakhir = await Geolocator.getLastKnownPosition();
      if (terakhir != null) return terakhir;
      throw const LokasiException(GalatLokasi.gagal);
    }
  }

  /// Label koordinat singkat, misalnya `-6.2088°, 106.8456°`.
  static String labelKoordinat(double lintang, double bujur) =>
      '${lintang.toStringAsFixed(4)}°, ${bujur.toStringAsFixed(4)}°';
}
