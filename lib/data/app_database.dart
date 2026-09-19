import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'amalan_bawaan.dart';

const String _namaBerkasDb = 'catatan_amalan.db';
const int _versiDb = 3;

/// Pembuka database SQLite lokal. Seluruh data aplikasi tersimpan di perangkat,
/// tidak ada sinkronisasi ke mana pun.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _buka();

  Future<Database> _buka() async {
    final factory = _factory();
    final direktori = await _direktoriDb(factory);
    return factory.openDatabase(
      p.join(direktori, _namaBerkasDb),
      options: OpenDatabaseOptions(
        version: _versiDb,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _buatSkema,
        onUpgrade: _tingkatkanSkema,
      ),
    );
  }

  /// Membuka database di memori. Dipakai pengujian agar tidak menyentuh disk.
  ///
  /// `singleInstance: false` penting di sini: tanpa itu, semua pemanggilan
  /// dengan jalur `:memory:` yang sama akan mendapat instance yang sudah ada,
  /// sehingga `onCreate` tidak pernah dijalankan ulang antar-tes.
  ///
  /// [tanpaIsolate] dipakai oleh uji widget. `testWidgets` berjalan di atas
  /// waktu palsu, dan pesan dari isolate pekerja tidak pernah sampai di sana,
  /// sehingga setiap operasi database akan menggantung. Varian tanpa isolate
  /// menyelesaikannya lewat antrean microtask yang tetap diputar oleh waktu
  /// palsu.
  ///
  /// Beri [jalur] bila pengujian butuh berkas sungguhan, misalnya untuk menguji
  /// migrasi yang mengharuskan database ditutup lalu dibuka lagi.
  static Future<Database> dalamMemori({
    bool isiBawaan = false,
    bool tanpaIsolate = false,
    String? jalur,
  }) async {
    sqfliteFfiInit();
    final factory = tanpaIsolate
        ? databaseFactoryFfiNoIsolate
        : databaseFactoryFfi;
    return factory.openDatabase(
      jalur ?? inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _versiDb,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, versi) async {
          await _buatTabel(db);
          if (isiBawaan) await _isiAmalanBawaan(db);
        },
        onUpgrade: _tingkatkanSkema,
      ),
    );
  }

  /// Di desktop tidak ada plugin native, jadi SQLite dipanggil lewat FFI.
  /// Di Android dan iOS dipakai plugin resminya.
  static bool get _desktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  DatabaseFactory _factory() {
    if (!_desktop) return databaseFactorySqflitePlugin;
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  Future<String> _direktoriDb(DatabaseFactory factory) async {
    // Di desktop, lokasi bawaan FFI mengikuti direktori kerja; simpan di
    // folder data aplikasi agar catatan tidak tercecer di samping berkas exe.
    if (_desktop) {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      return dir.path;
    }
    return factory.getDatabasesPath();
  }

  static Future<void> _buatSkema(Database db, int versi) async {
    await _buatTabel(db);
    await _isiAmalanBawaan(db);
  }

  static Future<void> _buatTabel(Database db) async {
    await db.execute('''
      CREATE TABLE amalan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        catatan TEXT,
        kategori TEXT NOT NULL,
        waktu TEXT NOT NULL,
        target INTEGER NOT NULL DEFAULT 1,
        satuan TEXT NOT NULL DEFAULT 'kali',
        ikon TEXT NOT NULL DEFAULT 'ceklis',
        urutan INTEGER NOT NULL DEFAULT 0,
        dibuat_pada TEXT NOT NULL,
        diarsipkan_pada TEXT,
        menit_pengingat INTEGER,
        sholat TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE catatan_harian (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amalan_id INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        jumlah INTEGER NOT NULL DEFAULT 0,
        diperbarui_pada TEXT NOT NULL,
        UNIQUE (amalan_id, tanggal) ON CONFLICT REPLACE,
        FOREIGN KEY (amalan_id) REFERENCES amalan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_catatan_tanggal ON catatan_harian (tanggal)',
    );

    await db.execute('''
      CREATE TABLE pengaturan (
        kunci TEXT PRIMARY KEY,
        nilai TEXT NOT NULL
      )
    ''');

    await db.execute(_buatTabelJadwal);
  }

  /// Simpanan jadwal sholat resmi hasil unduhan, agar tetap ada saat luring.
  static const _buatTabelJadwal = '''
    CREATE TABLE IF NOT EXISTS jadwal_sholat (
      lokasi TEXT NOT NULL,
      tanggal TEXT NOT NULL,
      subuh TEXT,
      dzuhur TEXT,
      ashar TEXT,
      maghrib TEXT,
      isya TEXT,
      PRIMARY KEY (lokasi, tanggal)
    )
  ''';

  static Future<void> _isiAmalanBawaan(Database db) async {
    final batch = db.batch();
    for (final amalan in amalanBawaan()) {
      batch.insert('amalan', amalan.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _tingkatkanSkema(
    Database db,
    int versiLama,
    int versiBaru,
  ) async {
    // v2: jam pengingat per amalan, tautan ke sholat wajib, dan tabel
    // pengaturan untuk lokasi serta preferensi notifikasi.
    if (versiLama < 2) {
      await db.execute('ALTER TABLE amalan ADD COLUMN menit_pengingat INTEGER');
      await db.execute('ALTER TABLE amalan ADD COLUMN sholat TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pengaturan (
          kunci TEXT PRIMARY KEY,
          nilai TEXT NOT NULL
        )
      ''');
      await _tautkanSholatBawaan(db);
    }

    // v3: simpanan jadwal sholat resmi hasil unduhan.
    if (versiLama < 3) {
      await db.execute(_buatTabelJadwal);
    }
  }

  /// Menautkan amalan sholat bawaan ke waktu sholatnya, supaya pengguna lama
  /// ikut mendapat jadwal otomatis tanpa harus menyunting satu per satu.
  static Future<void> _tautkanSholatBawaan(Database db) async {
    const tautan = {
      'Sholat Subuh': 'subuh',
      'Sholat Dzuhur': 'dzuhur',
      'Sholat Ashar': 'ashar',
      'Sholat Maghrib': 'maghrib',
      'Sholat Isya': 'isya',
    };
    final batch = db.batch();
    tautan.forEach((nama, sholat) {
      batch.update(
        'amalan',
        {'sholat': sholat},
        where: 'nama = ? AND sholat IS NULL',
        whereArgs: [nama],
      );
    });
    await batch.commit(noResult: true);
  }

  Future<void> tutup() async {
    await _db?.close();
    _db = null;
  }
}
