import 'package:sqflite/sqflite.dart';

import '../core/tanggal.dart';
import 'models/amalan.dart';
import 'statistik_service.dart';

/// Satu-satunya jalur baca/tulis ke database lokal.
class AmalanRepository {
  AmalanRepository(this._db);

  final Database _db;

  static const _tabelAmalan = 'amalan';
  static const _tabelCatatan = 'catatan_harian';

  Future<List<Amalan>> muatAmalan() async {
    final baris = await _db.query(_tabelAmalan, orderBy: 'urutan ASC, id ASC');
    return baris.map(Amalan.fromMap).toList();
  }

  /// Memuat seluruh catatan menjadi peta tanggal -> amalan -> jumlah.
  /// Volumenya kecil (satu baris per amalan per hari) sehingga aman dimuat
  /// sekaligus, dan membuat seluruh grafik bisa dihitung tanpa kueri ulang.
  Future<PetaCatatan> muatSemuaCatatan() async {
    final baris = await _db.query(
      _tabelCatatan,
      columns: ['amalan_id', 'tanggal', 'jumlah'],
      where: 'jumlah > 0',
    );

    final peta = <String, Map<int, int>>{};
    for (final b in baris) {
      final tanggal = b['tanggal'] as String;
      final amalanId = b['amalan_id'] as int;
      final jumlah = (b['jumlah'] as int?) ?? 0;
      (peta[tanggal] ??= <int, int>{})[amalanId] = jumlah;
    }
    return peta;
  }

  Future<Amalan> tambahAmalan(Amalan amalan) async {
    final urutan = amalan.urutan != 0
        ? amalan.urutan
        : ((await _urutanTerakhir()) + 1);
    final data = amalan.copyWith(urutan: urutan).toMap()..remove('id');
    final id = await _db.insert(_tabelAmalan, data);
    return amalan.copyWith(id: id, urutan: urutan);
  }

  Future<void> perbaruiAmalan(Amalan amalan) async {
    assert(amalan.id != null, 'Amalan harus punya id untuk diperbarui');
    await _db.update(
      _tabelAmalan,
      amalan.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [amalan.id],
    );
  }

  /// Menghapus amalan beserta seluruh riwayatnya (ON DELETE CASCADE).
  Future<void> hapusAmalan(int id) async {
    await _db.delete(_tabelAmalan, where: 'id = ?', whereArgs: [id]);
  }

  /// Menonaktifkan amalan mulai [sejak] tanpa menghapus riwayat lama.
  Future<void> arsipkanAmalan(int id, {DateTime? sejak}) async {
    await _db.update(
      _tabelAmalan,
      {'diarsipkan_pada': kunciTanggal(sejak ?? DateTime.now())},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> aktifkanAmalan(int id) async {
    await _db.update(
      _tabelAmalan,
      {'diarsipkan_pada': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Menyimpan urutan baru sesuai susunan [idTerurut].
  Future<void> simpanUrutan(List<int> idTerurut) async {
    final batch = _db.batch();
    for (var i = 0; i < idTerurut.length; i++) {
      batch.update(
        _tabelAmalan,
        {'urutan': i},
        where: 'id = ?',
        whereArgs: [idTerurut[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Menyimpan capaian satu amalan pada satu hari. Jumlah nol berarti catatan
  /// dihapus agar database tidak menyimpan baris kosong.
  Future<void> simpanCapaian({
    required int amalanId,
    required DateTime tanggal,
    required int jumlah,
  }) async {
    final kunci = kunciTanggal(tanggal);
    if (jumlah <= 0) {
      await _db.delete(
        _tabelCatatan,
        where: 'amalan_id = ? AND tanggal = ?',
        whereArgs: [amalanId, kunci],
      );
      return;
    }

    await _db.insert(_tabelCatatan, {
      'amalan_id': amalanId,
      'tanggal': kunci,
      'jumlah': jumlah,
      'diperbarui_pada': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Menghapus semua catatan pada satu hari, dipakai tombol "kosongkan hari".
  Future<void> kosongkanHari(DateTime tanggal) async {
    await _db.delete(
      _tabelCatatan,
      where: 'tanggal = ?',
      whereArgs: [kunciTanggal(tanggal)],
    );
  }

  Future<int> _urutanTerakhir() async {
    final hasil = await _db.rawQuery(
      'SELECT COALESCE(MAX(urutan), -1) AS maks FROM $_tabelAmalan',
    );
    return (hasil.first['maks'] as int?) ?? -1;
  }
}
