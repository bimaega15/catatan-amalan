import 'package:catatan_amalan/core/tanggal.dart';
import 'package:catatan_amalan/data/amalan_repository.dart';
import 'package:catatan_amalan/data/app_database.dart';
import 'package:catatan_amalan/data/cadangan_repository.dart';
import 'package:catatan_amalan/data/pengaturan_repository.dart';
import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:catatan_amalan/data/models/pengaturan.dart';
import 'package:catatan_amalan/main.dart';
import 'package:catatan_amalan/screens/form_amalan.dart';
import 'package:catatan_amalan/screens/pengaturan_screen.dart';
import 'package:catatan_amalan/screens/riwayat_screen.dart';
import 'package:catatan_amalan/screens/statistik_screen.dart';
import 'package:catatan_amalan/state/amalan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji rakitan: memasang aplikasi di atas database memori lalu menelusuri
/// keempat halaman. Selain memastikan alurnya jalan, tes ini menangkap luapan
/// tata letak karena galat render akan menggagalkan pengujian.
void main() {
  late Database db;
  late AmalanRepository repo;

  setUpAll(() => initializeDateFormatting('id'));

  setUp(() async {
    // Tanpa isolate: lihat catatan pada AppDatabase.dalamMemori.
    db = await AppDatabase.dalamMemori(tanpaIsolate: true);
    repo = AmalanRepository(db);
  });

  tearDown(() async => db.close());

  /// Memakai ukuran layar ponsel agar tata letak diuji pada lebar sebenarnya.
  void aturLayarPonsel(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pasang(WidgetTester tester) async {
    aturLayarPonsel(tester);
    final kontroler = AmalanController(
      repo,
      pengaturanRepo: PengaturanRepository(db),
      cadanganRepo: CadanganRepository(db),
    );
    await kontroler.muat();
    await tester.pumpWidget(AplikasiCatatanAmalan(kontroler: kontroler));
    await tester.pumpAndSettle();
  }

  /// Menggulir daftar di dalam [halaman] sampai [target] terlihat.
  Future<void> gulirKe(WidgetTester tester, Type halaman, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      // `.first` karena beberapa halaman memuat daftar bersarang (misalnya
      // kisi kalender); yang terluar adalah yang perlu digulir.
      scrollable: find
          .descendant(
            of: find.byType(halaman),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<Amalan> tambah({
    required String nama,
    int target = 1,
    String satuan = 'kali',
    WaktuAmalan waktu = WaktuAmalan.pagi,
    KategoriAmalan kategori = KategoriAmalan.dzikir,
    int? menitPengingat,
    SholatWajib? sholat,
  }) => repo.tambahAmalan(
    Amalan(
      nama: nama,
      kategori: kategori,
      waktu: waktu,
      target: target,
      satuan: satuan,
      dibuatPada: hariIni().subtract(const Duration(days: 30)),
      menitPengingat: menitPengingat,
      sholat: sholat,
    ),
  );

  testWidgets('menampilkan keadaan kosong saat belum ada amalan', (
    tester,
  ) async {
    await pasang(tester);

    expect(find.text('Belum ada amalan'), findsOneWidget);
    expect(find.text('Catatan Amalan'), findsOneWidget);
  });

  testWidgets('mencentang amalan menaikkan capaian harian', (tester) async {
    await tambah(nama: 'Dzikir Pagi');
    await pasang(tester);

    expect(find.text('Dzikir Pagi'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 dari 1 amalan tuntas'), findsOneWidget);

    await tester.tap(find.text('Dzikir Pagi'));
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 dari 1 amalan tuntas'), findsOneWidget);
    expect(find.text('Sudah dikerjakan'), findsOneWidget);

    // Mengetuk lagi membatalkan tanda selesai.
    await tester.tap(find.text('Dzikir Pagi'));
    await tester.pumpAndSettle();
    expect(find.text('0 dari 1 amalan tuntas'), findsOneWidget);
  });

  testWidgets('amalan berupa hitungan naik per langkah', (tester) async {
    await tambah(nama: 'Istighfar', target: 100, waktu: WaktuAmalan.bebas);
    await pasang(tester);

    expect(find.text('0 / 100 kali'), findsOneWidget);

    await tester.tap(find.text('Istighfar'));
    await tester.pumpAndSettle();
    expect(find.text('10 / 100 kali'), findsOneWidget);

    await tester.tap(find.text('Istighfar'));
    await tester.pumpAndSettle();
    expect(find.text('20 / 100 kali'), findsOneWidget);

    // Tombol kurangi muncul setelah ada capaian.
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('10 / 100 kali'), findsOneWidget);
  });

  testWidgets('halaman performa menggambar seluruh grafik', (tester) async {
    final amalan = await tambah(
      nama: 'Sholat Subuh',
      kategori: KategoriAmalan.sholat,
    );
    for (var i = 0; i < 5; i++) {
      await repo.simpanCapaian(
        amalanId: amalan.id!,
        tanggal: hariIni().subtract(Duration(days: i)),
        jumlah: 1,
      );
    }

    await pasang(tester);
    await tester.tap(find.text('Performa'));
    await tester.pumpAndSettle();

    expect(find.text('Rata-rata capaian · 30 Hari'), findsOneWidget);
    expect(find.text('Hari beruntun'), findsOneWidget);
    expect(find.text('Capaian harian'), findsOneWidget);

    await gulirKe(tester, StatistikScreen, find.text('Tren capaian'));
    await gulirKe(tester, StatistikScreen, find.text('Porsi per kategori'));
    expect(find.text('Sholat'), findsOneWidget);

    await gulirKe(tester, StatistikScreen, find.text('Konsistensi per amalan'));
    expect(find.text('5/30 hari'), findsOneWidget);
  });

  testWidgets('mengganti periode memperbarui angka utama', (tester) async {
    final amalan = await tambah(nama: 'Dzikir Pagi');
    await repo.simpanCapaian(
      amalanId: amalan.id!,
      tanggal: hariIni(),
      jumlah: 1,
    );

    await pasang(tester);
    await tester.tap(find.text('Performa'));
    await tester.pumpAndSettle();

    expect(find.text('Rata-rata capaian · 30 Hari'), findsOneWidget);

    await tester.tap(find.text('7 Hari'));
    await tester.pumpAndSettle();

    expect(find.text('Rata-rata capaian · 7 Hari'), findsOneWidget);
    // Satu dari tujuh hari tuntas.
    expect(find.text('14%'), findsOneWidget);
  });

  testWidgets('riwayat menampilkan kalender dan detail satu hari', (
    tester,
  ) async {
    final amalan = await tambah(
      nama: 'Tilawah',
      target: 5,
      satuan: 'halaman',
      kategori: KategoriAmalan.quran,
    );
    await repo.simpanCapaian(
      amalanId: amalan.id!,
      tanggal: hariIni(),
      jumlah: 5,
    );

    await pasang(tester);
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text(formatBulanTahun(hariIni())), findsOneWidget);
    await gulirKe(tester, RiwayatScreen, find.text('Hari tercatat'));

    await tester.tap(find.text('${hariIni().day}').first);
    await tester.pumpAndSettle();

    expect(find.text(formatTanggalPanjang(hariIni())), findsOneWidget);
    expect(find.text('5 / 5 halaman'), findsOneWidget);
  });

  testWidgets('menambah amalan lewat formulir', (tester) async {
    await pasang(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Amalan'));
    await tester.pumpAndSettle();

    expect(find.text('Amalan baru'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama amalan'),
      'Sholat Dhuha',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sunnah'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tambahkan amalan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambahkan amalan'));
    await tester.pumpAndSettle();

    expect(find.text('Amalan baru'), findsNothing, reason: 'lembar tertutup');
    expect(find.text('Sholat Dhuha'), findsOneWidget);

    final tersimpan = await repo.muatAmalan();
    expect(tersimpan.single.nama, 'Sholat Dhuha');
    expect(tersimpan.single.kategori, KategoriAmalan.sunnah);
  });

  testWidgets('formulir menolak nama kosong', (tester) async {
    await pasang(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Amalan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tambahkan amalan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambahkan amalan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama amalan belum diisi'), findsOneWidget);
    expect(await repo.muatAmalan(), isEmpty);
  });

  testWidgets('halaman kelola bisa mengarsipkan amalan', (tester) async {
    await tambah(nama: 'Dzikir Petang', waktu: WaktuAmalan.sore);
    await pasang(tester);

    await tester.tap(find.text('Amalan').last);
    await tester.pumpAndSettle();

    expect(find.text('Daftar Amalan'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();

    expect(find.text('Diarsipkan'), findsOneWidget);
    expect((await repo.muatAmalan()).single.diarsipkan, isTrue);
  });

  testWidgets('kartu amalan menampilkan jam pengingat', (tester) async {
    await tambah(nama: 'Belajar Bahasa Inggris', menitPengingat: 21 * 60 + 30);
    await tambah(nama: 'Sedekah', waktu: WaktuAmalan.bebas);
    await pasang(tester);

    expect(find.text('21:30'), findsOneWidget);
    // Amalan tanpa pengingat tidak menampilkan jam apa pun.
    expect(find.textContaining(':'), findsOneWidget);
  });

  testWidgets('tanpa lokasi, kartu sholat menampilkan nama waktunya', (
    tester,
  ) async {
    await tambah(
      nama: 'Sholat Subuh',
      kategori: KategoriAmalan.sholat,
      sholat: SholatWajib.subuh,
    );
    await pasang(tester);

    expect(find.text('Sholat Subuh'), findsOneWidget);
    // Jamnya belum bisa dihitung, tapi kartunya tetap menyebut jadwalnya.
    expect(find.text('Subuh'), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
    // Dan aplikasi menjelaskan cara memunculkan jamnya.
    expect(find.text('Jam sholat belum muncul'), findsOneWidget);
  });

  testWidgets('setelah lokasi disetel, kartu sholat menampilkan jamnya', (
    tester,
  ) async {
    await tambah(
      nama: 'Sholat Subuh',
      kategori: KategoriAmalan.sholat,
      sholat: SholatWajib.subuh,
    );
    // Jakarta.
    await PengaturanRepository(
      db,
    ).simpan(const Pengaturan(lintang: -6.2088, bujur: 106.8456));

    await pasang(tester);

    // Ajakan setel lokasi menghilang begitu koordinatnya ada.
    expect(find.text('Jam sholat belum muncul'), findsNothing);
    expect(find.text('Subuh'), findsNothing);

    // Subuh di Jakarta selalu jatuh di jam 04 atau 05 waktu setempat.
    final jam = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => RegExp(r'^0[45]:\d{2}$').hasMatch(t));
    expect(jam, isNotEmpty, reason: 'jam Subuh seharusnya tampil di kartu');
  });

  testWidgets('ajakan lokasi tidak muncul bila tak ada amalan sholat', (
    tester,
  ) async {
    await tambah(nama: 'Dzikir Pagi', menitPengingat: 6 * 60);
    await pasang(tester);

    expect(find.text('Jam sholat belum muncul'), findsNothing);
    expect(find.text('06:00'), findsOneWidget);
  });

  testWidgets('halaman pengaturan menampilkan seluruh bagiannya', (
    tester,
  ) async {
    await tambah(nama: 'Dzikir Pagi', menitPengingat: 6 * 60);
    await pasang(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Lokasi'), findsOneWidget);
    expect(find.text('Jadwal sholat'), findsOneWidget);
    expect(
      find.text('Setel lokasi lebih dulu untuk melihat jadwalnya.'),
      findsOneWidget,
    );

    await gulirKe(tester, PengaturanScreen, find.text('Ekspor ke Excel'));
    expect(find.text('Ekspor seluruh data (SQL)'), findsOneWidget);
    expect(find.text('Impor dari berkas SQL'), findsOneWidget);
  });

  testWidgets('formulir menawarkan pengingat jam tetap dan jadwal sholat', (
    tester,
  ) async {
    await pasang(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Amalan'));
    await tester.pumpAndSettle();

    await gulirKe(tester, FormAmalan, find.text('Pengingat'));
    expect(find.widgetWithText(ChoiceChip, 'Tanpa pengingat'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Jam tetap'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'Ikut jadwal sholat'),
      findsOneWidget,
    );
    expect(
      find.text('Amalan ini tidak akan mengirim notifikasi.'),
      findsOneWidget,
    );
  });
}
