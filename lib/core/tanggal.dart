import 'package:intl/intl.dart';

/// Utilitas tanggal. Seluruh aplikasi memakai tanggal tanpa jam sebagai
/// identitas satu hari, dengan kunci `yyyy-MM-dd` untuk penyimpanan.
const String _localeId = 'id';

DateTime tglSaja(DateTime waktu) =>
    DateTime(waktu.year, waktu.month, waktu.day);

DateTime hariIni() => tglSaja(DateTime.now());

String kunciTanggal(DateTime tanggal) =>
    '${tanggal.year.toString().padLeft(4, '0')}-'
    '${tanggal.month.toString().padLeft(2, '0')}-'
    '${tanggal.day.toString().padLeft(2, '0')}';

DateTime tanggalDariKunci(String kunci) => DateTime.parse(kunci);

bool tanggalSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Selisih hari kalender antara dua tanggal (b - a).
int selisihHari(DateTime a, DateTime b) =>
    tglSaja(b).difference(tglSaja(a)).inDays;

/// Daftar tanggal berurutan dari yang terlama ke terbaru, berakhir di [akhir].
List<DateTime> rentangHariTerakhir(int jumlahHari, {DateTime? akhir}) {
  final ujung = tglSaja(akhir ?? DateTime.now());
  return List<DateTime>.generate(
    jumlahHari,
    (i) => ujung.subtract(Duration(days: jumlahHari - 1 - i)),
  );
}

/// Senin pada pekan yang memuat [tanggal].
DateTime awalPekan(DateTime tanggal) {
  final hari = tglSaja(tanggal);
  return hari.subtract(Duration(days: hari.weekday - DateTime.monday));
}

String formatTanggalPanjang(DateTime tanggal) =>
    DateFormat('EEEE, d MMMM yyyy', _localeId).format(tanggal);

String formatTanggalPendek(DateTime tanggal) =>
    DateFormat('d MMM yyyy', _localeId).format(tanggal);

String formatTanggalSingkat(DateTime tanggal) =>
    DateFormat('d MMM', _localeId).format(tanggal);

String formatBulanTahun(DateTime tanggal) =>
    DateFormat('MMMM yyyy', _localeId).format(tanggal);

String formatHariSingkat(DateTime tanggal) =>
    DateFormat('EEE', _localeId).format(tanggal);

/// Label ramah untuk tanggal aktif: "Hari Ini", "Kemarin", atau tanggal penuh.
String labelRelatif(DateTime tanggal) {
  final beda = selisihHari(tanggal, DateTime.now());
  return switch (beda) {
    0 => 'Hari Ini',
    1 => 'Kemarin',
    -1 => 'Besok',
    _ => formatTanggalPendek(tanggal),
  };
}

String sapaanWaktu(DateTime waktu) {
  final jam = waktu.hour;
  if (jam < 11) return 'Selamat pagi';
  if (jam < 15) return 'Selamat siang';
  if (jam < 18) return 'Selamat sore';
  return 'Selamat malam';
}
