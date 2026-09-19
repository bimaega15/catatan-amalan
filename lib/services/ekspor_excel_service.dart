import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../core/tanggal.dart';
import '../data/models/amalan.dart';
import '../data/statistik_service.dart';

/// Menyusun berkas Excel berisi seluruh catatan.
///
/// Tiga lembar dengan sudut pandang berbeda: daftar amalan, catatan mentah per
/// hari, dan rekap harian. Lembar mentah dibuat "panjang" (satu baris per
/// amalan per hari) supaya gampang dijadikan pivot di Excel.
class EksporExcelService {
  const EksporExcelService._();

  static Uint8List susun({
    required List<Amalan> amalan,
    required PetaCatatan catatan,
    DateTime? sampai,
  }) {
    final excel = Excel.createExcel();
    final bawaan = excel.getDefaultSheet();

    _lembarAmalan(excel, amalan);
    _lembarCatatan(excel, amalan, catatan);
    _lembarRekap(excel, amalan, catatan, sampai ?? hariIni());

    // Lembar kosong bawaan dihapus terakhir; menghapusnya lebih awal membuat
    // paket ini membuat ulang lembar default.
    if (bawaan != null) excel.delete(bawaan);

    final data = excel.encode();
    if (data == null) {
      throw StateError('Berkas Excel gagal dibentuk.');
    }
    return Uint8List.fromList(data);
  }

  static void _lembarAmalan(Excel excel, List<Amalan> amalan) {
    final lembar = excel['Amalan'];
    lembar.appendRow([
      TextCellValue('Nama'),
      TextCellValue('Kategori'),
      TextCellValue('Waktu'),
      TextCellValue('Target'),
      TextCellValue('Satuan'),
      TextCellValue('Pengingat'),
      TextCellValue('Catatan'),
      TextCellValue('Dibuat'),
      TextCellValue('Diarsipkan'),
    ]);

    for (final a in amalan) {
      lembar.appendRow([
        TextCellValue(a.nama),
        TextCellValue(a.kategori.label),
        TextCellValue(a.waktu.label),
        IntCellValue(a.target),
        TextCellValue(a.satuan),
        TextCellValue(labelPengingat(a)),
        TextCellValue(a.catatan ?? ''),
        TextCellValue(kunciTanggal(a.dibuatPada)),
        TextCellValue(
          a.diarsipkanPada == null ? '' : kunciTanggal(a.diarsipkanPada!),
        ),
      ]);
    }
  }

  static void _lembarCatatan(
    Excel excel,
    List<Amalan> amalan,
    PetaCatatan catatan,
  ) {
    final lembar = excel['Catatan Harian'];
    lembar.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Amalan'),
      TextCellValue('Kategori'),
      TextCellValue('Jumlah'),
      TextCellValue('Target'),
      TextCellValue('Satuan'),
      TextCellValue('Tuntas'),
    ]);

    final perId = {for (final a in amalan) a.id: a};
    final tanggal = catatan.keys.toList()..sort();

    for (final kunci in tanggal) {
      final hari = catatan[kunci]!;
      final ids = hari.keys.toList()..sort();
      for (final id in ids) {
        final a = perId[id];
        if (a == null) continue;
        final jumlah = hari[id]!;
        lembar.appendRow([
          TextCellValue(kunci),
          TextCellValue(a.nama),
          TextCellValue(a.kategori.label),
          IntCellValue(jumlah),
          IntCellValue(a.target),
          TextCellValue(a.satuan),
          TextCellValue(a.selesaiDengan(jumlah) ? 'Ya' : 'Belum'),
        ]);
      }
    }
  }

  static void _lembarRekap(
    Excel excel,
    List<Amalan> amalan,
    PetaCatatan catatan,
    DateTime sampai,
  ) {
    final lembar = excel['Rekap Harian'];
    lembar.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Amalan berlaku'),
      TextCellValue('Tuntas'),
      TextCellValue('Capaian %'),
    ]);

    final tanggal = catatan.keys.toList()..sort();
    if (tanggal.isEmpty) return;

    final mulai = tanggalDariKunci(tanggal.first);
    final jumlahHari = selisihHari(mulai, sampai) + 1;
    if (jumlahHari <= 0) return;

    final hari = List<DateTime>.generate(
      jumlahHari,
      (i) => mulai.add(Duration(days: i)),
    );

    for (final r in StatistikService.ringkasanRentang(amalan, catatan, hari)) {
      lembar.appendRow([
        TextCellValue(kunciTanggal(r.tanggal)),
        IntCellValue(r.jumlahAmalan),
        IntCellValue(r.jumlahSelesai),
        IntCellValue(r.persen),
      ]);
    }
  }

  /// Keterangan jam pengingat yang bisa dibaca manusia.
  static String labelPengingat(Amalan amalan) {
    final sholat = amalan.sholat;
    if (sholat != null) return 'Jadwal ${sholat.label}';
    final menit = amalan.menitPengingat;
    if (menit == null) return '';
    return formatMenit(menit);
  }
}
