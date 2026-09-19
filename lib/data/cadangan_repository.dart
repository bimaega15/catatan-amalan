import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Ekspor dan impor seluruh isi database sebagai berkas `.sql`.
///
/// Berkas hasil ekspor sengaja berupa SQL biasa yang bisa dibaca dan dijalankan
/// alat lain. Sebaliknya, saat mengimpor hanya pernyataan `INSERT` ke tabel
/// yang dikenal yang dijalankan: struktur tabel tetap milik aplikasi, sehingga
/// berkas dari versi lama tetap bisa dipulihkan dan berkas asing tidak bisa
/// menjalankan perintah sembarangan.
class CadanganRepository {
  CadanganRepository(this._db);

  final Database _db;

  /// Urutannya penting saat memulihkan: induk lebih dulu, lalu anaknya.
  static const tabelCadangan = ['amalan', 'catatan_harian', 'pengaturan'];

  Future<String> keSql() async {
    final penyangga = StringBuffer()
      ..writeln('-- Cadangan Catatan Amalan')
      ..writeln('-- Dibuat: ${DateTime.now().toIso8601String()}')
      ..writeln('-- Versi skema: ${await _db.getVersion()}')
      ..writeln('--')
      ..writeln('-- Untuk memulihkan, gunakan menu Impor di dalam aplikasi.')
      ..writeln()
      ..writeln('PRAGMA foreign_keys = OFF;')
      ..writeln('BEGIN TRANSACTION;')
      ..writeln();

    for (final tabel in tabelCadangan) {
      final skema = await _db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        [tabel],
      );
      final buatTabel = skema.isEmpty ? null : skema.first['sql'] as String?;

      penyangga.writeln('-- Tabel $tabel');
      penyangga.writeln('DROP TABLE IF EXISTS $tabel;');
      if (buatTabel != null) penyangga.writeln('$buatTabel;');

      final baris = await _db.query(tabel);
      for (final b in baris) {
        final kolom = b.keys.toList();
        final nilai = kolom.map((k) => _literal(b[k])).join(', ');
        penyangga.writeln(
          'INSERT INTO $tabel (${kolom.join(', ')}) VALUES ($nilai);',
        );
      }
      penyangga.writeln();
    }

    penyangga
      ..writeln('COMMIT;')
      ..writeln('PRAGMA foreign_keys = ON;');
    return penyangga.toString();
  }

  /// Mengganti seluruh isi database dengan data dari [isi].
  ///
  /// Berjalan dalam satu transaksi: kalau ada satu pernyataan yang gagal,
  /// data lama tetap utuh. Mengembalikan jumlah baris yang dipulihkan.
  Future<int> dariSql(String isi) async {
    final pernyataan = pecahPernyataan(isi);
    final sisipan = <String>[];

    for (final p in pernyataan) {
      final jenis = _jenisPernyataan(p);
      if (jenis == _Jenis.sisip) {
        sisipan.add(p);
      } else if (jenis == _Jenis.asing) {
        throw FormatException(
          'Berkas memuat perintah yang tidak dikenali: '
          '${p.length > 60 ? '${p.substring(0, 60)}…' : p}',
        );
      }
      // Pernyataan struktur (DROP/CREATE/PRAGMA/BEGIN/COMMIT) sengaja diabaikan.
    }

    if (sisipan.isEmpty) {
      throw const FormatException(
        'Tidak ada data yang bisa dipulihkan dari berkas ini.',
      );
    }

    return _db.transaction((txn) async {
      for (final tabel in tabelCadangan.reversed) {
        await txn.delete(tabel);
      }
      for (final p in sisipan) {
        await txn.execute(p);
      }
      return sisipan.length;
    });
  }

  /// Memecah teks SQL menjadi pernyataan, dengan menghormati tanda kutip dan
  /// komentar sehingga titik koma di dalam teks tidak ikut memotong.
  @visibleForTesting
  static List<String> pecahPernyataan(String isi) {
    final hasil = <String>[];
    final sekarang = StringBuffer();
    var dalamKutip = false;

    for (var i = 0; i < isi.length; i++) {
      final huruf = isi[i];

      if (!dalamKutip) {
        // Komentar baris: lewati sampai akhir baris.
        if (huruf == '-' && i + 1 < isi.length && isi[i + 1] == '-') {
          while (i < isi.length && isi[i] != '\n') {
            i++;
          }
          continue;
        }
        if (huruf == ';') {
          _tambah(hasil, sekarang);
          continue;
        }
      }

      if (huruf == "'") {
        // '' di dalam teks berarti satu petik, bukan penutup.
        if (dalamKutip && i + 1 < isi.length && isi[i + 1] == "'") {
          sekarang.write("''");
          i++;
          continue;
        }
        dalamKutip = !dalamKutip;
      }

      sekarang.write(huruf);
    }

    _tambah(hasil, sekarang);
    return hasil;
  }

  static void _tambah(List<String> hasil, StringBuffer penyangga) {
    final teks = penyangga.toString().trim();
    penyangga.clear();
    if (teks.isNotEmpty) hasil.add(teks);
  }

  static _Jenis _jenisPernyataan(String pernyataan) {
    final normal = pernyataan.trimLeft().toUpperCase();

    for (final awalan in const [
      'PRAGMA',
      'BEGIN',
      'COMMIT',
      'END',
      'DROP TABLE',
      'CREATE TABLE',
      'CREATE INDEX',
      'CREATE UNIQUE INDEX',
      'DELETE FROM',
    ]) {
      if (normal.startsWith(awalan)) return _Jenis.struktur;
    }

    if (normal.startsWith('INSERT INTO')) {
      final nama = RegExp(
        r'^INSERT\s+INTO\s+[`"\[]?(\w+)',
        caseSensitive: false,
      ).firstMatch(pernyataan)?.group(1);
      if (nama != null && tabelCadangan.contains(nama)) return _Jenis.sisip;
    }

    return _Jenis.asing;
  }

  static String _literal(Object? nilai) {
    if (nilai == null) return 'NULL';
    if (nilai is num) return '$nilai';
    return "'${nilai.toString().replaceAll("'", "''")}'";
  }
}

enum _Jenis { sisip, struktur, asing }
