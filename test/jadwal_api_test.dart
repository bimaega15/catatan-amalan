import 'dart:convert';

import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:catatan_amalan/data/wilayah_indonesia.dart';
import 'package:catatan_amalan/services/jadwal_sholat_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Menyusun jawaban tiruan berbentuk sama dengan API Aladhan.
String _jawaban(List<Map<String, Object?>> hari) =>
    jsonEncode({'code': 200, 'status': 'OK', 'data': hari});

Map<String, Object?> _hari({
  required String tanggal,
  String zona = 'Asia/Jakarta',
  Map<String, Object?>? waktu,
}) => {
  'timings':
      waktu ??
      {
        // Akhiran zona sengaja disertakan: API menuliskannya seperti ini.
        'Fajr': '04:27 (WIB)',
        'Sunrise': '05:44 (WIB)',
        'Dhuhr': '11:46 (WIB)',
        'Asr': '14:58 (WIB)',
        'Maghrib': '17:49 (WIB)',
        'Isha': '18:58 (WIB)',
      },
  'date': {
    'gregorian': {'date': tanggal},
  },
  'meta': {'timezone': zona},
};

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('membaca jadwal sebulan beserta jamnya', () {
    final hasil = JadwalSholatApi.baca(
      _jawaban([_hari(tanggal: '19-09-2026'), _hari(tanggal: '20-09-2026')]),
    );

    expect(hasil.keys, ['2026-09-19', '2026-09-20']);
    expect(hasil['2026-09-19'], hasLength(5));

    // Diperiksa sebagai saat UTC supaya hasilnya tidak bergantung zona waktu
    // mesin penguji: 04:27 WIB sama dengan 21:27 UTC sehari sebelumnya.
    final subuh = hasil['2026-09-19']![SholatWajib.subuh]!;
    expect(subuh.toUtc(), DateTime.utc(2026, 9, 18, 21, 27));

    // Harus berupa waktu lokal perangkat, bukan UTC. Sempat keliru: hasilnya
    // memakai `tz.local` yang masih UTC, sehingga Subuh tampil sebagai 21:26.
    expect(subuh.isUtc, isFalse);
    expect(
      subuh.millisecondsSinceEpoch,
      DateTime.utc(2026, 9, 18, 21, 27).millisecondsSinceEpoch,
    );
  });

  test('jam diterjemahkan dari zona lokasi, bukan zona perangkat', () {
    final hasil = JadwalSholatApi.baca(
      _jawaban([
        _hari(
          tanggal: '19-09-2026',
          zona: 'Asia/Jayapura',
          waktu: const {
            'Fajr': '04:27 (WIT)',
            'Dhuhr': '11:46 (WIT)',
            'Asr': '14:58 (WIT)',
            'Maghrib': '17:49 (WIT)',
            'Isha': '18:58 (WIT)',
          },
        ),
      ]),
    );

    // Jayapura UTC+9, jadi 04:27 di sana sama dengan 19:27 UTC sehari lalu.
    final subuh = hasil['2026-09-19']![SholatWajib.subuh]!.toUtc();
    expect(subuh, DateTime.utc(2026, 9, 18, 19, 27));
  });

  test('hari dengan jam tak lengkap dilewati', () {
    final hasil = JadwalSholatApi.baca(
      _jawaban([
        _hari(tanggal: '19-09-2026'),
        _hari(
          tanggal: '20-09-2026',
          waktu: const {'Fajr': '04:27', 'Dhuhr': '11:46'},
        ),
      ]),
    );

    expect(hasil.keys, ['2026-09-19']);
  });

  test('zona waktu yang tidak dikenal dilewati', () {
    expect(
      () => JadwalSholatApi.baca(
        _jawaban([_hari(tanggal: '19-09-2026', zona: 'Mars/Olympus')]),
      ),
      throwsA(isA<JadwalApiException>()),
    );
  });

  test('jawaban kosong ditolak dengan pesan yang jelas', () {
    expect(
      () => JadwalSholatApi.baca(_jawaban([])),
      throwsA(isA<JadwalApiException>()),
    );
    expect(
      () => JadwalSholatApi.baca('{"code":200}'),
      throwsA(isA<JadwalApiException>()),
    );
  });

  group('daftar wilayah', () {
    test('mencakup seluruh 38 provinsi', () {
      final provinsi = wilayahIndonesia.map((w) => w.provinsi).toSet();
      expect(provinsi, hasLength(38));
    });

    test('koordinatnya masuk akal untuk Indonesia', () {
      for (final w in wilayahIndonesia) {
        expect(
          w.lintang,
          inInclusiveRange(-11, 6),
          reason: '${w.nama} lintangnya di luar Indonesia',
        );
        expect(
          w.bujur,
          inInclusiveRange(95, 141),
          reason: '${w.nama} bujurnya di luar Indonesia',
        );
      }
    });

    test('labelnya menggabungkan kota dan provinsi', () {
      final jakarta = cariWilayahPersis('Jakarta')!;
      expect(jakarta.label, 'Jakarta, DKI Jakarta');
    });

    test('pencarian cocok untuk nama kota maupun provinsi', () {
      expect(cariWilayah('yogya').single.nama, 'Yogyakarta');
      expect(
        cariWilayah('papua').map((w) => w.provinsi).toSet(),
        everyElement(contains('Papua')),
      );
      expect(cariWilayah('kota antah berantah'), isEmpty);
      expect(cariWilayah('  '), hasLength(wilayahIndonesia.length));
    });

    test('tebakan zona waktu hanya untuk zona Indonesia', () {
      expect(tebakWilayahDariZona(const Duration(hours: 7))?.nama, 'Jakarta');
      expect(tebakWilayahDariZona(const Duration(hours: 8))?.nama, 'Makassar');
      expect(tebakWilayahDariZona(const Duration(hours: 9))?.nama, 'Jayapura');
      expect(tebakWilayahDariZona(const Duration(hours: 1)), isNull);
      expect(tebakWilayahDariZona(const Duration(hours: -5)), isNull);
    });
  });

  test('zona waktu yang dipakai pengujian tersedia', () {
    // Memastikan basis data zona waktu benar-benar termuat; tanpa ini
    // pembacaan jadwal akan diam-diam melewati semua hari.
    expect(tz.getLocation('Asia/Jakarta').name, 'Asia/Jakarta');
  });
}
