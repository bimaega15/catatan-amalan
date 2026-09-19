import 'package:catatan_amalan/core/tanggal.dart';
import 'package:catatan_amalan/data/amalan_repository.dart';
import 'package:catatan_amalan/data/app_database.dart';
import 'package:catatan_amalan/data/cadangan_repository.dart';
import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:catatan_amalan/data/models/pengaturan.dart';
import 'package:catatan_amalan/data/pengaturan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late AmalanRepository amalanRepo;
  late PengaturanRepository pengaturanRepo;
  late CadanganRepository cadangan;

  final ini = hariIni();

  setUp(() async {
    db = await AppDatabase.dalamMemori();
    amalanRepo = AmalanRepository(db);
    pengaturanRepo = PengaturanRepository(db);
    cadangan = CadanganRepository(db);
  });

  tearDown(() async => db.close());

  Future<Amalan> isiContoh() async {
    final amalan = await amalanRepo.tambahAmalan(
      Amalan(
        // Tanda petik sengaja dipakai: ekspor harus meng-escape-nya.
        nama: "Tilawah Al-Qur'an",
        catatan: "Ba'da Subuh",
        kategori: KategoriAmalan.quran,
        waktu: WaktuAmalan.pagi,
        target: 5,
        satuan: 'halaman',
        dibuatPada: ini.subtract(const Duration(days: 3)),
        menitPengingat: 5 * 60 + 15,
      ),
    );
    await amalanRepo.simpanCapaian(
      amalanId: amalan.id!,
      tanggal: ini,
      jumlah: 3,
    );
    await pengaturanRepo.simpan(
      const Pengaturan(lintang: -6.2088, bujur: 106.8456),
    );
    return amalan;
  }

  group('pecahPernyataan', () {
    test('memisahkan berdasarkan titik koma dan membuang komentar', () {
      final hasil = CadanganRepository.pecahPernyataan('''
        -- ini komentar
        INSERT INTO amalan (nama) VALUES ('A');
        INSERT INTO amalan (nama) VALUES ('B');
      ''');

      expect(hasil, hasLength(2));
      expect(hasil.first, contains("'A'"));
    });

    test('titik koma di dalam teks tidak ikut memotong', () {
      final hasil = CadanganRepository.pecahPernyataan(
        "INSERT INTO amalan (nama) VALUES ('Dzikir; Pagi');",
      );

      expect(hasil, hasLength(1));
      expect(hasil.single, contains('Dzikir; Pagi'));
    });

    test('petik ganda di dalam teks tetap utuh', () {
      final hasil = CadanganRepository.pecahPernyataan(
        "INSERT INTO amalan (nama) VALUES ('Al-Qur''an');",
      );

      expect(hasil, hasLength(1));
      expect(hasil.single, contains("Al-Qur''an"));
    });
  });

  test('ekspor memuat skema dan seluruh baris', () async {
    await isiContoh();

    final sql = await cadangan.keSql();

    expect(sql, contains('CREATE TABLE amalan'));
    expect(sql, contains('INSERT INTO amalan'));
    expect(sql, contains('INSERT INTO catatan_harian'));
    expect(sql, contains('INSERT INTO pengaturan'));
    // Petik satu di dalam nilai harus digandakan agar SQL-nya tetap sah.
    expect(sql, contains("Al-Qur''an"));
  });

  test('ekspor lalu impor mengembalikan data yang sama', () async {
    final asli = await isiContoh();
    final sql = await cadangan.keSql();

    // Kosongkan, lalu pulihkan dari berkas.
    await amalanRepo.hapusAmalan(asli.id!);
    expect(await amalanRepo.muatAmalan(), isEmpty);

    final jumlah = await cadangan.dariSql(sql);
    expect(jumlah, greaterThan(0));

    final pulih = (await amalanRepo.muatAmalan()).single;
    expect(pulih.nama, "Tilawah Al-Qur'an");
    expect(pulih.catatan, "Ba'da Subuh");
    expect(pulih.target, 5);
    expect(pulih.satuan, 'halaman');
    expect(pulih.menitPengingat, 5 * 60 + 15);

    final catatan = await amalanRepo.muatSemuaCatatan();
    expect(catatan[kunciTanggal(ini)], {pulih.id: 3});

    final pengaturan = await pengaturanRepo.muat();
    expect(pengaturan.lintang, closeTo(-6.2088, 0.0001));
  });

  test('impor mengganti data lama, bukan menambah', () async {
    await isiContoh();
    final sql = await cadangan.keSql();

    await amalanRepo.tambahAmalan(
      Amalan(
        nama: 'Amalan yang seharusnya hilang',
        kategori: KategoriAmalan.lainnya,
        waktu: WaktuAmalan.bebas,
        dibuatPada: ini,
      ),
    );
    expect(await amalanRepo.muatAmalan(), hasLength(2));

    await cadangan.dariSql(sql);

    final daftar = await amalanRepo.muatAmalan();
    expect(daftar, hasLength(1));
    expect(daftar.single.nama, "Tilawah Al-Qur'an");
  });

  test('impor menolak perintah di luar daftar tabel yang dikenal', () async {
    await isiContoh();

    expect(
      () => cadangan.dariSql("INSERT INTO sqlite_master (name) VALUES ('x');"),
      throwsA(isA<FormatException>()),
    );
    // Data lama tidak boleh tersentuh.
    expect(await amalanRepo.muatAmalan(), hasLength(1));
  });

  test('impor berkas tanpa data memberi pesan yang jelas', () async {
    expect(
      () => cadangan.dariSql('-- kosong\nPRAGMA foreign_keys = OFF;'),
      throwsA(isA<FormatException>()),
    );
  });

  test('impor yang gagal di tengah jalan tidak merusak data lama', () async {
    await isiContoh();
    final sql = await cadangan.keSql();

    // Pernyataan terakhir menyebut kolom yang tidak ada.
    final rusak = '$sql\nINSERT INTO amalan (kolom_ngawur) VALUES (\'x\');';

    await expectLater(() => cadangan.dariSql(rusak), throwsA(anything));

    final daftar = await amalanRepo.muatAmalan();
    expect(daftar, hasLength(1), reason: 'transaksi harus dibatalkan utuh');
    expect(daftar.single.nama, "Tilawah Al-Qur'an");
  });
}
