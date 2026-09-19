import 'package:catatan_amalan/data/models/amalan.dart';
import 'package:catatan_amalan/data/models/pengaturan.dart';
import 'package:catatan_amalan/services/jadwal_sholat_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jakarta, dipakai sebagai acuan uji.
const _jakarta = Pengaturan(lintang: -6.2088, bujur: 106.8456);

Amalan _amalan({SholatWajib? sholat, int? menitPengingat}) => Amalan(
  id: 1,
  nama: 'Uji',
  kategori: KategoriAmalan.sholat,
  waktu: WaktuAmalan.bebas,
  dibuatPada: DateTime(2020),
  sholat: sholat,
  menitPengingat: menitPengingat,
);

void main() {
  final tanggal = DateTime(2026, 9, 19);

  test('tanpa lokasi jadwalnya kosong', () {
    expect(JadwalSholatService.hitung(const Pengaturan(), tanggal), isNull);
  });

  test('jadwal Jakarta berurutan sepanjang hari', () {
    final jadwal = JadwalSholatService.hitung(_jakarta, tanggal)!;

    final urut = [
      jadwal[SholatWajib.subuh]!,
      jadwal[SholatWajib.dzuhur]!,
      jadwal[SholatWajib.ashar]!,
      jadwal[SholatWajib.maghrib]!,
      jadwal[SholatWajib.isya]!,
    ];

    for (var i = 1; i < urut.length; i++) {
      expect(
        urut[i].isAfter(urut[i - 1]),
        isTrue,
        reason: '${urut[i]} seharusnya setelah ${urut[i - 1]}',
      );
    }
  });

  test('waktu Dzuhur Jakarta jatuh di sekitar tengah hari setempat', () {
    final jadwal = JadwalSholatService.hitung(_jakarta, tanggal)!;
    // Diperiksa dalam UTC agar hasilnya tidak bergantung zona waktu mesin
    // penguji. Tengah hari matahari di Jakarta ada di sekitar 04:55 UTC.
    final dzuhurUtc = jadwal[SholatWajib.dzuhur]!.toUtc();

    expect(dzuhurUtc.hour, 4);
    expect(dzuhurUtc.minute, inInclusiveRange(30, 59));
  });

  test('mazhab Hanafi membuat Ashar lebih lambat daripada Syafi\'i', () {
    final syafii = JadwalSholatService.hitung(_jakarta, tanggal)!;
    final hanafi = JadwalSholatService.hitung(
      _jakarta.copyWith(mazhab: MazhabAshar.hanafi),
      tanggal,
    )!;

    expect(
      hanafi[SholatWajib.ashar]!.isAfter(syafii[SholatWajib.ashar]!),
      isTrue,
    );
  });

  test('metode perhitungan berbeda menggeser waktu Subuh', () {
    final mwl = JadwalSholatService.hitung(_jakarta, tanggal)!;
    final ummAlQura = JadwalSholatService.hitung(
      _jakarta.copyWith(metode: MetodeSholat.ummAlQura),
      tanggal,
    )!;

    // Subuh ditentukan sudut matahari yang berbeda tiap metode, jadi
    // selisihnya harus terasa.
    expect(
      mwl[SholatWajib.subuh]!
          .difference(ummAlQura[SholatWajib.subuh]!)
          .inMinutes
          .abs(),
      greaterThan(1),
    );
    // Dzuhur mengikuti posisi matahari; metode hanya menambah koreksi menit.
    expect(
      mwl[SholatWajib.dzuhur]!
          .difference(ummAlQura[SholatWajib.dzuhur]!)
          .inMinutes
          .abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('jadwal bergeser dari hari ke hari', () {
    final hariIni = JadwalSholatService.hitung(_jakarta, tanggal)!;
    final duaBulanLagi = JadwalSholatService.hitung(
      _jakarta,
      tanggal.add(const Duration(days: 60)),
    )!;

    expect(
      hariIni[SholatWajib.maghrib]!.difference(
        duaBulanLagi[SholatWajib.maghrib]!,
      ),
      isNot(Duration.zero),
    );
  });

  group('waktuPengingat', () {
    test('amalan tanpa pengingat tidak punya waktu', () {
      expect(JadwalSholatService.waktuPengingat(_amalan(), tanggal), isNull);
    });

    test('jam tetap dipakai apa adanya', () {
      final waktu = JadwalSholatService.waktuPengingat(
        _amalan(menitPengingat: 21 * 60 + 30),
        tanggal,
      )!;

      expect(waktu.hour, 21);
      expect(waktu.minute, 30);
      expect(waktu.day, tanggal.day);
    });

    test('amalan tertaut sholat mengambil jam dari jadwal', () {
      final jadwal = JadwalSholatService.hitung(_jakarta, tanggal)!;
      final waktu = JadwalSholatService.waktuPengingat(
        _amalan(sholat: SholatWajib.maghrib),
        tanggal,
        jadwal: jadwal,
      );

      expect(waktu, jadwal[SholatWajib.maghrib]);
    });

    test('amalan tertaut sholat tanpa jadwal belum punya waktu', () {
      expect(
        JadwalSholatService.waktuPengingat(
          _amalan(sholat: SholatWajib.subuh),
          tanggal,
        ),
        isNull,
      );
    });
  });
}
