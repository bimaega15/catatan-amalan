import '../core/tanggal.dart';
import 'models/amalan.dart';

/// Daftar amalan yang langsung tersedia saat aplikasi pertama kali dibuka.
/// Pengguna bebas mengubah, menonaktifkan, atau menghapus semuanya.
///
/// Lima sholat fardhu ditautkan ke [SholatWajib], jadi jam pengingatnya
/// mengikuti jadwal sholat harian di lokasi pengguna, bukan jam tetap.
List<Amalan> amalanBawaan({DateTime? dibuatPada}) {
  final tanggal = tglSaja(dibuatPada ?? DateTime.now());
  var urutan = 0;

  Amalan buat({
    required String nama,
    required KategoriAmalan kategori,
    required WaktuAmalan waktu,
    int target = 1,
    String satuan = 'kali',
    required String ikon,
    String? catatan,
    SholatWajib? sholat,
  }) {
    return Amalan(
      nama: nama,
      catatan: catatan,
      kategori: kategori,
      waktu: waktu,
      target: target,
      satuan: satuan,
      ikon: ikon,
      urutan: urutan++,
      dibuatPada: tanggal,
      sholat: sholat,
    );
  }

  return [
    buat(
      nama: 'Sholat Subuh',
      kategori: KategoriAmalan.sholat,
      waktu: WaktuAmalan.pagi,
      ikon: 'subuh',
      sholat: SholatWajib.subuh,
    ),
    buat(
      nama: 'Dzikir Pagi',
      kategori: KategoriAmalan.dzikir,
      waktu: WaktuAmalan.pagi,
      ikon: 'tasbih',
      catatan: 'Dibaca setelah Subuh hingga terbit matahari',
    ),
    buat(
      nama: 'Sholat Dhuha',
      kategori: KategoriAmalan.sunnah,
      waktu: WaktuAmalan.pagi,
      ikon: 'matahari',
    ),
    buat(
      nama: 'Tilawah Al-Qur\'an',
      kategori: KategoriAmalan.quran,
      waktu: WaktuAmalan.bebas,
      target: 5,
      satuan: 'halaman',
      ikon: 'quran',
    ),
    buat(
      nama: 'Sholat Dzuhur',
      kategori: KategoriAmalan.sholat,
      waktu: WaktuAmalan.siang,
      ikon: 'masjid',
      sholat: SholatWajib.dzuhur,
    ),
    buat(
      nama: 'Sholat Ashar',
      kategori: KategoriAmalan.sholat,
      waktu: WaktuAmalan.sore,
      ikon: 'masjid',
      sholat: SholatWajib.ashar,
    ),
    buat(
      nama: 'Dzikir Petang',
      kategori: KategoriAmalan.dzikir,
      waktu: WaktuAmalan.sore,
      ikon: 'senja',
      catatan: 'Dibaca setelah Ashar hingga Maghrib',
    ),
    buat(
      nama: 'Sholat Maghrib',
      kategori: KategoriAmalan.sholat,
      waktu: WaktuAmalan.malam,
      ikon: 'masjid',
      sholat: SholatWajib.maghrib,
    ),
    buat(
      nama: 'Sholat Isya',
      kategori: KategoriAmalan.sholat,
      waktu: WaktuAmalan.malam,
      ikon: 'masjid',
      sholat: SholatWajib.isya,
    ),
    buat(
      nama: 'Sholat Tahajud',
      kategori: KategoriAmalan.sunnah,
      waktu: WaktuAmalan.malam,
      ikon: 'bulan',
    ),
    buat(
      nama: 'Istighfar',
      kategori: KategoriAmalan.dzikir,
      waktu: WaktuAmalan.bebas,
      target: 100,
      ikon: 'hati',
    ),
    buat(
      nama: 'Sholawat',
      kategori: KategoriAmalan.dzikir,
      waktu: WaktuAmalan.bebas,
      target: 100,
      ikon: 'bintang',
    ),
    buat(
      nama: 'Sedekah',
      kategori: KategoriAmalan.sosial,
      waktu: WaktuAmalan.bebas,
      ikon: 'sedekah',
    ),
    buat(
      nama: 'Berbakti kepada Orang Tua',
      kategori: KategoriAmalan.sosial,
      waktu: WaktuAmalan.bebas,
      ikon: 'orangtua',
      catatan: 'Menelepon, mendoakan, atau membantu',
    ),
  ];
}
