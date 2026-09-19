import 'package:flutter/material.dart';

import '../../core/ikon_amalan.dart';
import '../../core/tanggal.dart';

/// Kelompok amalan.
///
/// Urutan deklarasi menentukan slot warna di [VizPalet.kategori], jadi menukar
/// urutannya berarti mengubah warna grafik — lakukan hanya setelah palet
/// divalidasi ulang.
enum KategoriAmalan {
  dzikir('Dzikir'),
  sholat('Sholat'),
  quran('Al-Qur\'an'),
  sunnah('Sunnah'),
  sosial('Sosial'),
  lainnya('Lainnya');

  const KategoriAmalan(this.label);

  final String label;

  static KategoriAmalan dariNama(String? nama) => values.firstWhere(
    (k) => k.name == nama,
    orElse: () => KategoriAmalan.lainnya,
  );
}

/// Waktu pengerjaan amalan, dipakai untuk mengelompokkan daftar harian.
enum WaktuAmalan {
  pagi('Pagi', 'Setelah Subuh hingga Dzuhur', Icons.wb_twilight),
  siang('Siang', 'Dzuhur hingga Ashar', Icons.wb_sunny_outlined),
  sore('Sore', 'Ashar hingga Maghrib', Icons.brightness_4_outlined),
  malam('Malam', 'Maghrib hingga Subuh', Icons.nightlight_outlined),
  bebas('Kapan Saja', 'Tidak terikat waktu', Icons.all_inclusive);

  const WaktuAmalan(this.label, this.keterangan, this.ikon);

  final String label;
  final String keterangan;
  final IconData ikon;

  static WaktuAmalan dariNama(String? nama) =>
      values.firstWhere((w) => w.name == nama, orElse: () => WaktuAmalan.bebas);
}

/// Lima sholat fardhu. Amalan yang ditautkan ke salah satunya memakai jam dari
/// jadwal sholat harian, bukan jam tetap, karena waktunya bergeser tiap hari
/// mengikuti posisi matahari di lokasi pengguna.
enum SholatWajib {
  subuh('Subuh'),
  dzuhur('Dzuhur'),
  ashar('Ashar'),
  maghrib('Maghrib'),
  isya('Isya');

  const SholatWajib(this.label);

  final String label;

  static SholatWajib? dariNama(String? nama) {
    if (nama == null) return null;
    for (final sholat in values) {
      if (sholat.name == nama) return sholat;
    }
    return null;
  }
}

/// Satu jenis amalan yang dipantau, misalnya "Dzikir Pagi" atau "Istighfar".
@immutable
class Amalan {
  const Amalan({
    this.id,
    required this.nama,
    this.catatan,
    required this.kategori,
    required this.waktu,
    this.target = 1,
    this.satuan = 'kali',
    this.ikon = ikonBawaan,
    this.urutan = 0,
    required this.dibuatPada,
    this.diarsipkanPada,
    this.menitPengingat,
    this.sholat,
  });

  final int? id;
  final String nama;
  final String? catatan;
  final KategoriAmalan kategori;
  final WaktuAmalan waktu;

  /// Jumlah yang harus dicapai agar amalan dianggap selesai dalam satu hari.
  final int target;
  final String satuan;
  final String ikon;
  final int urutan;
  final DateTime dibuatPada;

  /// Tanggal amalan dinonaktifkan. Amalan yang diarsipkan tidak lagi dihitung
  /// pada hari-hari setelah tanggal ini, tetapi riwayat lamanya tetap utuh.
  final DateTime? diarsipkanPada;

  /// Jam pengingat sebagai menit sejak tengah malam, atau null bila amalan ini
  /// tidak perlu diingatkan. Diabaikan bila [sholat] terisi.
  final int? menitPengingat;

  /// Bila terisi, jam pengingat diambil dari jadwal sholat hari itu.
  final SholatWajib? sholat;

  /// Amalan ini punya pengingat, entah dari jam tetap atau jadwal sholat.
  bool get adaPengingat => sholat != null || menitPengingat != null;

  bool get diarsipkan => diarsipkanPada != null;

  /// Amalan dengan target lebih dari satu dicatat memakai penghitung.
  bool get berupaHitungan => target > 1;

  IconData get ikonData => ikonAmalan(ikon);

  /// Besar penambahan tiap satu ketukan pada amalan berupa hitungan.
  int get langkah {
    if (target >= 100) return 10;
    if (target >= 30) return 5;
    return 1;
  }

  /// Apakah amalan ini termasuk dalam penilaian pada [tanggal].
  bool aktifPada(DateTime tanggal) {
    final hari = tglSaja(tanggal);
    if (hari.isBefore(tglSaja(dibuatPada))) return false;
    final arsip = diarsipkanPada;
    if (arsip != null && !hari.isBefore(tglSaja(arsip))) return false;
    return true;
  }

  bool selesaiDengan(int jumlah) => jumlah >= target;

  Amalan copyWith({
    int? id,
    String? nama,
    String? catatan,
    bool hapusCatatan = false,
    KategoriAmalan? kategori,
    WaktuAmalan? waktu,
    int? target,
    String? satuan,
    String? ikon,
    int? urutan,
    DateTime? dibuatPada,
    DateTime? diarsipkanPada,
    bool hapusArsip = false,
    int? menitPengingat,
    bool hapusPengingat = false,
    SholatWajib? sholat,
    bool hapusSholat = false,
  }) {
    return Amalan(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      catatan: hapusCatatan ? null : (catatan ?? this.catatan),
      kategori: kategori ?? this.kategori,
      waktu: waktu ?? this.waktu,
      target: target ?? this.target,
      satuan: satuan ?? this.satuan,
      ikon: ikon ?? this.ikon,
      urutan: urutan ?? this.urutan,
      dibuatPada: dibuatPada ?? this.dibuatPada,
      diarsipkanPada: hapusArsip
          ? null
          : (diarsipkanPada ?? this.diarsipkanPada),
      menitPengingat: hapusPengingat
          ? null
          : (menitPengingat ?? this.menitPengingat),
      sholat: hapusSholat ? null : (sholat ?? this.sholat),
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'nama': nama,
    'catatan': catatan,
    'kategori': kategori.name,
    'waktu': waktu.name,
    'target': target,
    'satuan': satuan,
    'ikon': ikon,
    'urutan': urutan,
    'dibuat_pada': kunciTanggal(dibuatPada),
    'diarsipkan_pada': diarsipkanPada == null
        ? null
        : kunciTanggal(diarsipkanPada!),
    'menit_pengingat': menitPengingat,
    'sholat': sholat?.name,
  };

  factory Amalan.fromMap(Map<String, Object?> baris) {
    final arsip = baris['diarsipkan_pada'] as String?;
    return Amalan(
      id: baris['id'] as int?,
      nama: baris['nama'] as String,
      catatan: baris['catatan'] as String?,
      kategori: KategoriAmalan.dariNama(baris['kategori'] as String?),
      waktu: WaktuAmalan.dariNama(baris['waktu'] as String?),
      target: (baris['target'] as int?) ?? 1,
      satuan: (baris['satuan'] as String?) ?? 'kali',
      ikon: (baris['ikon'] as String?) ?? ikonBawaan,
      urutan: (baris['urutan'] as int?) ?? 0,
      dibuatPada: tanggalDariKunci(baris['dibuat_pada'] as String),
      diarsipkanPada: arsip == null ? null : tanggalDariKunci(arsip),
      menitPengingat: baris['menit_pengingat'] as int?,
      sholat: SholatWajib.dariNama(baris['sholat'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Amalan &&
      other.id == id &&
      other.nama == nama &&
      other.catatan == catatan &&
      other.kategori == kategori &&
      other.waktu == waktu &&
      other.target == target &&
      other.satuan == satuan &&
      other.ikon == ikon &&
      other.urutan == urutan &&
      other.diarsipkanPada == diarsipkanPada &&
      other.menitPengingat == menitPengingat &&
      other.sholat == sholat;

  @override
  int get hashCode => Object.hash(
    id,
    nama,
    catatan,
    kategori,
    waktu,
    target,
    satuan,
    ikon,
    urutan,
    diarsipkanPada,
    menitPengingat,
    sholat,
  );
}

/// Pilihan satuan yang ditawarkan saat membuat amalan baru.
const List<String> satuanAmalan = [
  'kali',
  'halaman',
  'juz',
  'ayat',
  'rakaat',
  'menit',
  'lembar',
];
