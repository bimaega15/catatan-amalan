import 'package:flutter/foundation.dart';

/// Satu wilayah rujukan untuk perhitungan jadwal sholat.
@immutable
class Wilayah {
  const Wilayah(this.nama, this.provinsi, this.lintang, this.bujur);

  final String nama;
  final String provinsi;
  final double lintang;
  final double bujur;

  String get label => '$nama, $provinsi';
}

/// Daftar kota rujukan, satu sampai beberapa per provinsi, mencakup seluruh 38
/// provinsi Indonesia.
///
/// Daftar ini ada supaya pengguna bisa memunculkan jadwal sholat tanpa GPS dan
/// tanpa internet: cukup pilih kota terdekat. Selisih beberapa puluh kilometer
/// hanya menggeser waktu sholat dalam hitungan menit, jadi kota provinsi sudah
/// cukup untuk sebagian besar keperluan; yang ingin persis bisa memakai GPS.
///
/// Koordinatnya diperiksa dengan membandingkan zona waktu yang dikembalikan
/// API Aladhan terhadap zona waktu provinsinya, sehingga salah tempat yang
/// mencolok akan ketahuan.
const List<Wilayah> wilayahIndonesia = [
  Wilayah('Banda Aceh', 'Aceh', 5.5483, 95.3238),
  Wilayah('Lhokseumawe', 'Aceh', 5.1801, 97.1507),
  Wilayah('Denpasar', 'Bali', -8.6705, 115.2126),
  Wilayah('Cilegon', 'Banten', -6.0025, 106.0114),
  Wilayah('Serang', 'Banten', -6.12, 106.1503),
  Wilayah('Tangerang', 'Banten', -6.1783, 106.6319),
  Wilayah('Bengkulu', 'Bengkulu', -3.7928, 102.2608),
  Wilayah('Yogyakarta', 'DI Yogyakarta', -7.7956, 110.3695),
  Wilayah('Jakarta', 'DKI Jakarta', -6.2088, 106.8456),
  Wilayah('Gorontalo', 'Gorontalo', 0.5435, 123.0568),
  Wilayah('Jambi', 'Jambi', -1.6101, 103.6131),
  Wilayah('Bandung', 'Jawa Barat', -6.9175, 107.6191),
  Wilayah('Bekasi', 'Jawa Barat', -6.2383, 106.9756),
  Wilayah('Bogor', 'Jawa Barat', -6.595, 106.8166),
  Wilayah('Cirebon', 'Jawa Barat', -6.732, 108.5523),
  Wilayah('Depok', 'Jawa Barat', -6.4025, 106.7942),
  Wilayah('Sukabumi', 'Jawa Barat', -6.9277, 106.93),
  Wilayah('Tasikmalaya', 'Jawa Barat', -7.3274, 108.2207),
  Wilayah('Magelang', 'Jawa Tengah', -7.4698, 110.2177),
  Wilayah('Pekalongan', 'Jawa Tengah', -6.8886, 109.6753),
  Wilayah('Purwokerto', 'Jawa Tengah', -7.4249, 109.2397),
  Wilayah('Salatiga', 'Jawa Tengah', -7.3305, 110.5084),
  Wilayah('Semarang', 'Jawa Tengah', -6.9932, 110.4203),
  Wilayah('Surakarta', 'Jawa Tengah', -7.5755, 110.8243),
  Wilayah('Tegal', 'Jawa Tengah', -6.8694, 109.1402),
  Wilayah('Banyuwangi', 'Jawa Timur', -8.2192, 114.3691),
  Wilayah('Jember', 'Jawa Timur', -8.1845, 113.6681),
  Wilayah('Kediri', 'Jawa Timur', -7.848, 112.0178),
  Wilayah('Madiun', 'Jawa Timur', -7.6298, 111.5239),
  Wilayah('Malang', 'Jawa Timur', -7.9666, 112.6326),
  Wilayah('Probolinggo', 'Jawa Timur', -7.7543, 113.2159),
  Wilayah('Surabaya', 'Jawa Timur', -7.2575, 112.7521),
  Wilayah('Pontianak', 'Kalimantan Barat', -0.0263, 109.3425),
  Wilayah('Singkawang', 'Kalimantan Barat', 0.9068, 108.9887),
  Wilayah('Banjarmasin', 'Kalimantan Selatan', -3.3186, 114.5944),
  Wilayah('Palangka Raya', 'Kalimantan Tengah', -2.21, 113.9213),
  Wilayah('Balikpapan', 'Kalimantan Timur', -1.2379, 116.8529),
  Wilayah('Bontang', 'Kalimantan Timur', 0.1324, 117.49),
  Wilayah('Samarinda', 'Kalimantan Timur', -0.5022, 117.1536),
  Wilayah('Tanjung Selor', 'Kalimantan Utara', 2.8375, 117.3661),
  Wilayah('Tarakan', 'Kalimantan Utara', 3.3273, 117.5766),
  Wilayah('Pangkal Pinang', 'Kepulauan Bangka Belitung', -2.1316, 106.1169),
  Wilayah('Batam', 'Kepulauan Riau', 1.0456, 104.0305),
  Wilayah('Tanjung Pinang', 'Kepulauan Riau', 0.9186, 104.4552),
  Wilayah('Bandar Lampung', 'Lampung', -5.3971, 105.2668),
  Wilayah('Metro', 'Lampung', -5.1131, 105.3067),
  Wilayah('Ambon', 'Maluku', -3.6954, 128.1814),
  Wilayah('Tual', 'Maluku', -5.64, 132.75),
  Wilayah('Ternate', 'Maluku Utara', 0.79, 127.38),
  Wilayah('Mataram', 'Nusa Tenggara Barat', -8.5833, 116.1167),
  Wilayah('Kupang', 'Nusa Tenggara Timur', -10.1772, 123.607),
  Wilayah('Jayapura', 'Papua', -2.5916, 140.669),
  Wilayah('Manokwari', 'Papua Barat', -0.8615, 134.062),
  Wilayah('Sorong', 'Papua Barat Daya', -0.8762, 131.2558),
  Wilayah('Wamena', 'Papua Pegunungan', -4.0983, 138.95),
  Wilayah('Merauke', 'Papua Selatan', -8.4932, 140.4018),
  Wilayah('Nabire', 'Papua Tengah', -3.3667, 135.5),
  Wilayah('Timika', 'Papua Tengah', -4.55, 136.8833),
  Wilayah('Dumai', 'Riau', 1.6667, 101.45),
  Wilayah('Pekanbaru', 'Riau', 0.5071, 101.4478),
  Wilayah('Mamuju', 'Sulawesi Barat', -2.6748, 118.8885),
  Wilayah('Makassar', 'Sulawesi Selatan', -5.1477, 119.4327),
  Wilayah('Palopo', 'Sulawesi Selatan', -2.9925, 120.1969),
  Wilayah('Parepare', 'Sulawesi Selatan', -4.0135, 119.6255),
  Wilayah('Palu', 'Sulawesi Tengah', -0.8917, 119.8707),
  Wilayah('Baubau', 'Sulawesi Tenggara', -5.47, 122.6167),
  Wilayah('Kendari', 'Sulawesi Tenggara', -3.9985, 122.5129),
  Wilayah('Bitung', 'Sulawesi Utara', 1.44, 125.12),
  Wilayah('Manado', 'Sulawesi Utara', 1.4748, 124.8421),
  Wilayah('Bukittinggi', 'Sumatera Barat', -0.3055, 100.3691),
  Wilayah('Padang', 'Sumatera Barat', -0.9471, 100.4172),
  Wilayah('Palembang', 'Sumatera Selatan', -2.9761, 104.7754),
  Wilayah('Medan', 'Sumatera Utara', 3.5952, 98.6722),
  Wilayah('Pematangsiantar', 'Sumatera Utara', 2.9595, 99.0687),
];

/// Menebak wilayah dari selisih zona waktu perangkat.
///
/// Dipakai hanya sebagai nilai awal agar jadwal langsung tampil saat aplikasi
/// pertama dibuka; pengguna tetap diminta memilih wilayahnya sendiri.
Wilayah? tebakWilayahDariZona(Duration selisih) {
  final jam = selisih.inMinutes / 60;
  return switch (jam) {
    7 => cariWilayahPersis('Jakarta'),
    8 => cariWilayahPersis('Makassar'),
    9 => cariWilayahPersis('Jayapura'),
    _ => null,
  };
}

Wilayah? cariWilayahPersis(String nama) {
  for (final w in wilayahIndonesia) {
    if (w.nama == nama) return w;
  }
  return null;
}

/// Menyaring daftar wilayah menurut nama kota atau provinsinya.
List<Wilayah> cariWilayah(String kata) {
  final kunci = kata.trim().toLowerCase();
  if (kunci.isEmpty) return wilayahIndonesia;
  return wilayahIndonesia
      .where(
        (w) =>
            w.nama.toLowerCase().contains(kunci) ||
            w.provinsi.toLowerCase().contains(kunci),
      )
      .toList();
}
