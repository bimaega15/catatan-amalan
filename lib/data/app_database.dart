import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'amalan_bawaan.dart';

const String _namaBerkasDb = 'catatan_amalan.db';
const int _versiDb = 1;

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
  static Future<Database> dalamMemori({
    bool isiBawaan = false,
    bool tanpaIsolate = false,
  }) async {
    sqfliteFfiInit();
    final factory = tanpaIsolate
        ? databaseFactoryFfiNoIsolate
        : databaseFactoryFfi;
    return factory.openDatabase(
      inMemoryDatabasePath,
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
        diarsipkan_pada TEXT
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
  }

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
    // Belum ada migrasi; disiapkan untuk versi skema berikutnya.
  }

  Future<void> tutup() async {
    await _db?.close();
    _db = null;
  }
}
