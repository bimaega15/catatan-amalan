import 'package:catatan_amalan/core/tanggal.dart';
import 'package:catatan_amalan/data/amalan_repository.dart';
import 'package:catatan_amalan/data/app_database.dart';
import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late AmalanRepository repo;

  final ini = hariIni();
  final kemarin = ini.subtract(const Duration(days: 1));

  setUp(() async {
    db = await AppDatabase.dalamMemori();
    repo = AmalanRepository(db);
  });

  tearDown(() async => db.close());

  Future<Amalan> buatAmalan({
    String nama = 'Dzikir Pagi',
    int target = 1,
    DateTime? dibuatPada,
  }) => repo.tambahAmalan(
    Amalan(
      nama: nama,
      kategori: KategoriAmalan.dzikir,
      waktu: WaktuAmalan.pagi,
      target: target,
      dibuatPada: dibuatPada ?? ini,
    ),
  );

  test('database baru dimulai tanpa amalan bila tidak diisi bawaan', () async {
    expect(await repo.muatAmalan(), isEmpty);
  });

  test('database bawaan menyediakan daftar amalan awal', () async {
    final dbBawaan = await AppDatabase.dalamMemori(isiBawaan: true);
    final daftar = await AmalanRepository(dbBawaan).muatAmalan();

    expect(daftar, isNotEmpty);
    expect(daftar.map((a) => a.nama), contains('Dzikir Pagi'));
    // Urutan tersimpan sesuai kolom urutan.
    expect(
      daftar.map((a) => a.urutan).toList(),
      List<int>.generate(daftar.length, (i) => i),
    );
    await dbBawaan.close();
  });

  test('menambah amalan memberi id dan urutan berikutnya', () async {
    final pertama = await buatAmalan(nama: 'Pertama');
    final kedua = await buatAmalan(nama: 'Kedua');

    expect(pertama.id, isNotNull);
    expect(kedua.urutan, greaterThan(pertama.urutan));
  });

  test('menyimpan capaian bersifat upsert per amalan per tanggal', () async {
    final amalan = await buatAmalan(target: 100);
    final id = amalan.id!;

    await repo.simpanCapaian(amalanId: id, tanggal: ini, jumlah: 30);
    await repo.simpanCapaian(amalanId: id, tanggal: ini, jumlah: 70);

    final catatan = await repo.muatSemuaCatatan();
    expect(catatan[kunciTanggal(ini)], {id: 70});

    final baris = await db.query('catatan_harian');
    expect(baris, hasLength(1), reason: 'baris ganda seharusnya tergantikan');
  });

  test('capaian nol menghapus barisnya', () async {
    final amalan = await buatAmalan();
    final id = amalan.id!;

    await repo.simpanCapaian(amalanId: id, tanggal: ini, jumlah: 1);
    await repo.simpanCapaian(amalanId: id, tanggal: ini, jumlah: 0);

    expect(await repo.muatSemuaCatatan(), isEmpty);
    expect(await db.query('catatan_harian'), isEmpty);
  });

  test('kosongkanHari hanya menghapus tanggal yang diminta', () async {
    final amalan = await buatAmalan();
    final id = amalan.id!;

    await repo.simpanCapaian(amalanId: id, tanggal: ini, jumlah: 1);
    await repo.simpanCapaian(amalanId: id, tanggal: kemarin, jumlah: 1);
    await repo.kosongkanHari(ini);

    final catatan = await repo.muatSemuaCatatan();
    expect(catatan.containsKey(kunciTanggal(ini)), isFalse);
    expect(catatan[kunciTanggal(kemarin)], {id: 1});
  });

  test('menghapus amalan juga menghapus riwayatnya', () async {
    final amalan = await buatAmalan();
    await repo.simpanCapaian(amalanId: amalan.id!, tanggal: ini, jumlah: 1);

    await repo.hapusAmalan(amalan.id!);

    expect(await repo.muatAmalan(), isEmpty);
    expect(await repo.muatSemuaCatatan(), isEmpty);
  });

  test('arsip menyimpan tanggalnya dan bisa diaktifkan kembali', () async {
    final amalan = await buatAmalan(
      dibuatPada: ini.subtract(const Duration(days: 7)),
    );

    await repo.arsipkanAmalan(amalan.id!, sejak: ini);
    var tersimpan = (await repo.muatAmalan()).single;
    expect(tersimpan.diarsipkan, isTrue);
    expect(tersimpan.diarsipkanPada, ini);
    expect(tersimpan.aktifPada(kemarin), isTrue);
    expect(tersimpan.aktifPada(ini), isFalse);

    await repo.aktifkanAmalan(amalan.id!);
    tersimpan = (await repo.muatAmalan()).single;
    expect(tersimpan.diarsipkan, isFalse);
  });

  test('perbaruiAmalan menyimpan perubahan lapangan', () async {
    final amalan = await buatAmalan();

    await repo.perbaruiAmalan(
      amalan.copyWith(
        nama: 'Istighfar',
        target: 100,
        satuan: 'kali',
        kategori: KategoriAmalan.sunnah,
        waktu: WaktuAmalan.malam,
        catatan: 'Sebelum tidur',
      ),
    );

    final tersimpan = (await repo.muatAmalan()).single;
    expect(tersimpan.nama, 'Istighfar');
    expect(tersimpan.target, 100);
    expect(tersimpan.berupaHitungan, isTrue);
    expect(tersimpan.kategori, KategoriAmalan.sunnah);
    expect(tersimpan.waktu, WaktuAmalan.malam);
    expect(tersimpan.catatan, 'Sebelum tidur');
  });

  test('simpanUrutan menulis ulang urutan tampilan', () async {
    final a = await buatAmalan(nama: 'A');
    final b = await buatAmalan(nama: 'B');
    final c = await buatAmalan(nama: 'C');

    await repo.simpanUrutan([c.id!, a.id!, b.id!]);

    final daftar = await repo.muatAmalan();
    expect(daftar.map((x) => x.nama).toList(), ['C', 'A', 'B']);
  });
}
