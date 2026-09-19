import 'dart:io';

import 'package:catatan_amalan/core/tanggal.dart';
import 'package:catatan_amalan/data/amalan_repository.dart';
import 'package:catatan_amalan/data/app_database.dart';
import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:catatan_amalan/services/ekspor_excel_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final ini = hariIni();

  group('ekspor Excel', () {
    final amalan = [
      Amalan(
        id: 1,
        nama: 'Dzikir Pagi',
        kategori: KategoriAmalan.dzikir,
        waktu: WaktuAmalan.pagi,
        dibuatPada: ini.subtract(const Duration(days: 2)),
        menitPengingat: 5 * 60 + 30,
      ),
      Amalan(
        id: 2,
        nama: 'Sholat Subuh',
        kategori: KategoriAmalan.sholat,
        waktu: WaktuAmalan.pagi,
        dibuatPada: ini.subtract(const Duration(days: 2)),
        sholat: SholatWajib.subuh,
      ),
      Amalan(
        id: 3,
        nama: 'Istighfar',
        kategori: KategoriAmalan.dzikir,
        waktu: WaktuAmalan.bebas,
        target: 100,
        dibuatPada: ini.subtract(const Duration(days: 2)),
      ),
    ];

    final catatan = {
      kunciTanggal(ini): {1: 1, 2: 1, 3: 40},
      kunciTanggal(ini.subtract(const Duration(days: 1))): {1: 1},
    };

    test('berisi tiga lembar dengan baris yang benar', () {
      final data = EksporExcelService.susun(
        amalan: amalan,
        catatan: catatan,
        sampai: ini,
      );
      final excel = Excel.decodeBytes(data);

      expect(
        excel.tables.keys,
        containsAll(<String>['Amalan', 'Catatan Harian', 'Rekap Harian']),
      );
      // Lembar kosong bawaan tidak boleh ikut terbawa.
      expect(excel.tables.keys, isNot(contains('Sheet1')));

      // Kepala tabel + satu baris per amalan.
      expect(excel.tables['Amalan']!.maxRows, amalan.length + 1);
      // Kepala tabel + satu baris per catatan.
      expect(excel.tables['Catatan Harian']!.maxRows, 4 + 1);
      // Kepala tabel + dua hari yang direkap.
      expect(excel.tables['Rekap Harian']!.maxRows, 2 + 1);
    });

    test('menulis jenis pengingat dalam bahasa manusia', () {
      final data = EksporExcelService.susun(amalan: amalan, catatan: catatan);
      final lembar = Excel.decodeBytes(data).tables['Amalan']!;

      String sel(int baris, int kolom) =>
          lembar.rows[baris][kolom]?.value?.toString() ?? '';

      expect(sel(1, 5), '05:30', reason: 'jam tetap');
      expect(sel(2, 5), 'Jadwal Subuh', reason: 'tertaut jadwal sholat');
      expect(sel(3, 5), '', reason: 'tanpa pengingat');
    });

    test('tanpa catatan pun berkasnya tetap sah', () {
      final data = EksporExcelService.susun(amalan: amalan, catatan: const {});
      final excel = Excel.decodeBytes(data);

      expect(excel.tables['Catatan Harian']!.maxRows, 1);
      expect(excel.tables['Rekap Harian']!.maxRows, 1);
    });
  });

  group('migrasi skema', () {
    late Directory folder;
    late String jalur;

    setUp(() async {
      sqfliteFfiInit();
      folder = await Directory.systemTemp.createTemp('catatan_amalan_uji');
      jalur = p.join(folder.path, 'uji.db');
    });

    tearDown(() async => folder.delete(recursive: true));

    /// Membuat database dengan skema versi 1 (tanpa jam pengingat, tautan
    /// sholat, maupun tabel pengaturan).
    Future<void> buatSkemaLama() async {
      final db = await databaseFactoryFfi.openDatabase(
        jalur,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
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
            await db.insert('amalan', {
              'nama': 'Sholat Subuh',
              'kategori': 'sholat',
              'waktu': 'pagi',
              'target': 1,
              'satuan': 'kali',
              'ikon': 'subuh',
              'urutan': 0,
              'dibuat_pada': kunciTanggal(
                ini.subtract(const Duration(days: 5)),
              ),
            });
            await db.insert('amalan', {
              'nama': 'Sedekah',
              'kategori': 'sosial',
              'waktu': 'bebas',
              'target': 1,
              'satuan': 'kali',
              'ikon': 'sedekah',
              'urutan': 1,
              'dibuat_pada': kunciTanggal(
                ini.subtract(const Duration(days: 5)),
              ),
            });
            await db.insert('catatan_harian', {
              'amalan_id': 1,
              'tanggal': kunciTanggal(ini),
              'jumlah': 1,
              'diperbarui_pada': DateTime.now().toIso8601String(),
            });
          },
        ),
      );
      await db.close();
    }

    test('v1 naik ke v2 tanpa kehilangan data', () async {
      await buatSkemaLama();

      final db = await AppDatabase.dalamMemori(jalur: jalur);
      final repo = AmalanRepository(db);

      final daftar = await repo.muatAmalan();
      expect(daftar.map((a) => a.nama), ['Sholat Subuh', 'Sedekah']);
      expect(await repo.muatSemuaCatatan(), isNotEmpty);

      // Kolom baru tersedia dan bernilai kosong untuk data lama.
      final sedekah = daftar.firstWhere((a) => a.nama == 'Sedekah');
      expect(sedekah.menitPengingat, isNull);
      expect(sedekah.sholat, isNull);

      // Sholat wajib bawaan ikut ditautkan ke jadwalnya.
      final subuh = daftar.firstWhere((a) => a.nama == 'Sholat Subuh');
      expect(subuh.sholat, SholatWajib.subuh);

      // Tabel pengaturan sudah ada dan bisa dipakai.
      expect(await db.query('pengaturan'), isEmpty);

      await db.close();
    });
  });
}
