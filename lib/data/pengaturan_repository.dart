import 'package:sqflite/sqflite.dart';

import 'models/pengaturan.dart';

/// Baca/tulis preferensi aplikasi pada tabel kunci-nilai `pengaturan`.
class PengaturanRepository {
  PengaturanRepository(this._db);

  final Database _db;

  static const _tabel = 'pengaturan';

  Future<Pengaturan> muat() async {
    final baris = await _db.query(_tabel);
    final nilai = {
      for (final b in baris) b['kunci'] as String: b['nilai'] as String,
    };
    return Pengaturan.fromMap(nilai);
  }

  /// Menulis seluruh preferensi sekaligus. Kunci yang tidak lagi terpakai
  /// (misalnya lokasi yang dihapus) ikut dibersihkan.
  Future<void> simpan(Pengaturan pengaturan) async {
    final data = pengaturan.toMap();
    final batch = _db.batch();
    batch.delete(
      _tabel,
      where: 'kunci NOT IN (${List.filled(data.length, '?').join(', ')})',
      whereArgs: data.keys.toList(),
    );
    data.forEach((kunci, nilai) {
      batch.insert(_tabel, {
        'kunci': kunci,
        'nilai': nilai,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }
}
