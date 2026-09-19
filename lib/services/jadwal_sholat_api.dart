import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/tanggal.dart';
import '../data/models/amalan.dart';
import '../data/models/pengaturan.dart';

/// Jadwal satu bulan: kunci tanggal `yyyy-MM-dd` -> waktu tiap sholat.
typedef JadwalBulanan = Map<String, Map<SholatWajib, DateTime>>;

/// Gagal mengambil jadwal dari API, dengan pesan yang siap ditampilkan.
class JadwalApiException implements Exception {
  const JadwalApiException(this.pesan);

  final String pesan;

  @override
  String toString() => 'JadwalApiException: $pesan';
}

/// Mengambil jadwal sholat resmi dari API Aladhan.
///
/// Dipakai untuk metode Kemenag RI (kode 20 di sana), yaitu jadwal yang sama
/// dengan yang dipakai di Indonesia. Diambil sebulan sekali jalan — satu
/// permintaan untuk 28–31 hari — lalu disimpan ke database, sehingga aplikasi
/// tetap menampilkan jadwal saat sedang luring.
class JadwalSholatApi {
  const JadwalSholatApi._();

  static const _host = 'api.aladhan.com';

  /// Sholat yang diambil, dipetakan dari nama di API.
  static const _pemetaan = {
    'Fajr': SholatWajib.subuh,
    'Dhuhr': SholatWajib.dzuhur,
    'Asr': SholatWajib.ashar,
    'Maghrib': SholatWajib.maghrib,
    'Isha': SholatWajib.isya,
  };

  static bool _zonaSiap = false;

  static Future<JadwalBulanan> ambilBulan({
    required double lintang,
    required double bujur,
    required MetodeSholat metode,
    required MazhabAshar mazhab,
    required int tahun,
    required int bulan,
    Duration batasWaktu = const Duration(seconds: 20),
  }) async {
    if (!_zonaSiap) {
      tzdata.initializeTimeZones();
      _zonaSiap = true;
    }

    final alamat = Uri.https(_host, '/v1/calendar/$tahun/$bulan', {
      'latitude': '$lintang',
      'longitude': '$bujur',
      'method': '${metode.kodeAladhan}',
      // 0 = Syafi'i (bayangan 1x), 1 = Hanafi (bayangan 2x).
      'school': mazhab == MazhabAshar.hanafi ? '1' : '0',
    });

    final klien = HttpClient()..connectionTimeout = batasWaktu;
    try {
      final permintaan = await klien.getUrl(alamat).timeout(batasWaktu);
      final tanggapan = await permintaan.close().timeout(batasWaktu);

      if (tanggapan.statusCode != HttpStatus.ok) {
        throw JadwalApiException(
          'Server jadwal menjawab ${tanggapan.statusCode}.',
        );
      }

      final isi = await tanggapan
          .transform(utf8.decoder)
          .join()
          .timeout(batasWaktu);
      return baca(isi);
    } on JadwalApiException {
      rethrow;
    } on SocketException {
      throw const JadwalApiException(
        'Tidak ada koneksi internet. Jadwal dihitung di perangkat dulu.',
      );
    } catch (e) {
      throw JadwalApiException('Jadwal gagal diambil: $e');
    } finally {
      klien.close(force: true);
    }
  }

  /// Membaca jawaban JSON dari API menjadi jadwal per hari.
  @visibleForTesting
  static JadwalBulanan baca(String isi) {
    final akar = jsonDecode(isi);
    if (akar is! Map<String, dynamic>) {
      throw const JadwalApiException('Bentuk jawaban server tidak dikenali.');
    }
    final hari = akar['data'];
    if (hari is! List) {
      throw const JadwalApiException('Server tidak mengirim data harian.');
    }

    final hasil = <String, Map<SholatWajib, DateTime>>{};
    for (final h in hari) {
      if (h is! Map) continue;
      final tanggal = _tanggal(h);
      final zona = _zona(h);
      if (tanggal == null || zona == null) continue;

      final waktu = h['timings'];
      if (waktu is! Map) continue;

      final sehari = <SholatWajib, DateTime>{};
      _pemetaan.forEach((nama, sholat) {
        final jam = _jam(waktu[nama]);
        if (jam == null) return;
        // Jam dari API memakai zona waktu lokasi, yang bisa berbeda dari zona
        // perangkat; dikonversi dulu supaya pengingat tetap tepat.
        //
        // Sengaja lewat saat epoch, bukan `TZDateTime.toLocal()`: yang terakhir
        // memakai `tz.local` milik paket timezone, dan itu masih UTC selama
        // `setLocalLocation` belum dipanggil — misalnya di desktop, tempat
        // notifikasi tidak dipasang. Akibatnya Subuh sempat tampil 21:26.
        final saat = tz.TZDateTime(
          zona,
          tanggal.year,
          tanggal.month,
          tanggal.day,
          jam.$1,
          jam.$2,
        );
        sehari[sholat] = DateTime.fromMillisecondsSinceEpoch(
          saat.millisecondsSinceEpoch,
        );
      });

      if (sehari.length == _pemetaan.length) {
        hasil[kunciTanggal(tanggal)] = sehari;
      }
    }

    if (hasil.isEmpty) {
      throw const JadwalApiException('Server tidak mengirim jadwal apa pun.');
    }
    return hasil;
  }

  static DateTime? _tanggal(Map<dynamic, dynamic> hari) {
    final teks = (hari['date'] as Map?)?['gregorian']?['date'];
    if (teks is! String) return null;
    // Bentuknya dd-MM-yyyy.
    final bagian = teks.split('-');
    if (bagian.length != 3) return null;
    final d = int.tryParse(bagian[0]);
    final m = int.tryParse(bagian[1]);
    final y = int.tryParse(bagian[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  static tz.Location? _zona(Map<dynamic, dynamic> hari) {
    final nama = (hari['meta'] as Map?)?['timezone'];
    if (nama is! String) return null;
    try {
      return tz.getLocation(nama);
    } catch (_) {
      return null;
    }
  }

  /// Membaca "04:27 (WIB)" menjadi (4, 27).
  static (int, int)? _jam(Object? nilai) {
    if (nilai is! String) return null;
    final cocok = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(nilai);
    if (cocok == null) return null;
    final jam = int.parse(cocok.group(1)!);
    final menit = int.parse(cocok.group(2)!);
    if (jam > 23 || menit > 59) return null;
    return (jam, menit);
  }
}
