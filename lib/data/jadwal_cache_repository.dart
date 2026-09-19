import 'package:sqflite/sqflite.dart';

import '../core/tanggal.dart';
import '../services/jadwal_sholat_api.dart';
import 'models/amalan.dart';
import 'models/pengaturan.dart';

/// Menyimpan jadwal sholat resmi hasil unduhan agar tetap tersedia saat luring.
///
/// Barisnya diberi label lokasi: begitu koordinat, metode, atau mazhab berubah,
/// kuncinya ikut berubah sehingga jadwal lama tidak pernah terpakai untuk
/// pengaturan baru.
class JadwalCacheRepository {
  JadwalCacheRepository(this._db);

  final Database _db;

  static const _tabel = 'jadwal_sholat';

  static const _kolom = {
    SholatWajib.subuh: 'subuh',
    SholatWajib.dzuhur: 'dzuhur',
    SholatWajib.ashar: 'ashar',
    SholatWajib.maghrib: 'maghrib',
    SholatWajib.isya: 'isya',
  };

  /// Label pengaturan yang memengaruhi hasil perhitungan. Koordinat dibulatkan
  /// ke tiga angka di belakang koma (kira-kira 100 meter) supaya pergeseran
  /// kecil dari GPS tidak membuang cache yang masih sahih.
  static String kunciLokasi(Pengaturan pengaturan) {
    final lintang = (pengaturan.lintang ?? 0).toStringAsFixed(3);
    final bujur = (pengaturan.bujur ?? 0).toStringAsFixed(3);
    return '$lintang,$bujur,${pengaturan.metode.kunci},'
        '${pengaturan.mazhab.kunci}';
  }

  Future<JadwalBulanan> muat(String lokasi) async {
    final baris = await _db.query(
      _tabel,
      where: 'lokasi = ?',
      whereArgs: [lokasi],
    );

    final hasil = <String, Map<SholatWajib, DateTime>>{};
    for (final b in baris) {
      final sehari = <SholatWajib, DateTime>{};
      var lengkap = true;
      _kolom.forEach((sholat, kolom) {
        final teks = b[kolom] as String?;
        final waktu = teks == null ? null : DateTime.tryParse(teks);
        if (waktu == null) {
          lengkap = false;
          return;
        }
        sehari[sholat] = waktu;
      });
      if (lengkap) hasil[b['tanggal'] as String] = sehari;
    }
    return hasil;
  }

  Future<void> simpan(String lokasi, JadwalBulanan jadwal) async {
    final batch = _db.batch();
    jadwal.forEach((tanggal, sehari) {
      batch.insert(_tabel, {
        'lokasi': lokasi,
        'tanggal': tanggal,
        for (final entri in _kolom.entries)
          entri.value: sehari[entri.key]?.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }

  /// Membuang jadwal milik pengaturan lain dan hari-hari yang sudah lewat.
  Future<void> rapikan(String lokasi, {DateTime? sebelum}) async {
    await _db.delete(_tabel, where: 'lokasi <> ?', whereArgs: [lokasi]);
    await _db.delete(
      _tabel,
      where: 'tanggal < ?',
      whereArgs: [kunciTanggal(sebelum ?? hariIni())],
    );
  }
}
