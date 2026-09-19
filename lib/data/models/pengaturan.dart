import 'package:flutter/foundation.dart';

/// Metode perhitungan jadwal sholat yang ditawarkan.
///
/// Nilai `kunci` sengaja sama dengan nama enum `CalculationMethod` milik paket
/// adhan, supaya pemetaannya langsung tanpa tabel terjemahan.
enum MetodeSholat {
  kemenag('muslim_world_league', 'Kemenag / MWL', 'Dipakai luas di Indonesia'),
  egyptian('egyptian', 'Mesir', 'Egyptian General Authority of Survey'),
  karachi('karachi', 'Karachi', 'University of Islamic Sciences, Karachi'),
  ummAlQura('umm_al_qura', 'Umm al-Qura', 'Makkah'),
  singapura('singapore', 'Singapura', 'MUIS Singapura'),
  turki('turkey', 'Turki', 'Diyanet İşleri Başkanlığı'),
  amerikaUtara('north_america', 'Amerika Utara', 'ISNA');

  const MetodeSholat(this.kunci, this.label, this.keterangan);

  final String kunci;
  final String label;
  final String keterangan;

  static MetodeSholat dariKunci(String? kunci) {
    for (final metode in values) {
      if (metode.kunci == kunci) return metode;
    }
    return MetodeSholat.kemenag;
  }
}

/// Mazhab penentu waktu Ashar.
enum MazhabAshar {
  syafii('shafi', 'Syafi\'i', 'Bayangan 1× (umum di Indonesia)'),
  hanafi('hanafi', 'Hanafi', 'Bayangan 2×');

  const MazhabAshar(this.kunci, this.label, this.keterangan);

  final String kunci;
  final String label;
  final String keterangan;

  static MazhabAshar dariKunci(String? kunci) =>
      kunci == MazhabAshar.hanafi.kunci
      ? MazhabAshar.hanafi
      : MazhabAshar.syafii;
}

/// Preferensi aplikasi. Disimpan sebagai pasangan kunci-nilai di database
/// supaya menambah pengaturan baru tidak perlu migrasi skema.
@immutable
class Pengaturan {
  const Pengaturan({
    this.lintang,
    this.bujur,
    this.labelLokasi,
    this.metode = MetodeSholat.kemenag,
    this.mazhab = MazhabAshar.syafii,
    this.notifikasiAktif = true,
    this.lokasiDiperbaruiPada,
  });

  final double? lintang;
  final double? bujur;

  /// Keterangan lokasi yang bisa dibaca manusia, misalnya koordinat singkat.
  final String? labelLokasi;

  final MetodeSholat metode;
  final MazhabAshar mazhab;
  final bool notifikasiAktif;
  final DateTime? lokasiDiperbaruiPada;

  bool get adaLokasi => lintang != null && bujur != null;

  Pengaturan copyWith({
    double? lintang,
    double? bujur,
    String? labelLokasi,
    MetodeSholat? metode,
    MazhabAshar? mazhab,
    bool? notifikasiAktif,
    DateTime? lokasiDiperbaruiPada,
    bool hapusLokasi = false,
  }) {
    if (hapusLokasi) {
      return Pengaturan(
        metode: metode ?? this.metode,
        mazhab: mazhab ?? this.mazhab,
        notifikasiAktif: notifikasiAktif ?? this.notifikasiAktif,
      );
    }
    return Pengaturan(
      lintang: lintang ?? this.lintang,
      bujur: bujur ?? this.bujur,
      labelLokasi: labelLokasi ?? this.labelLokasi,
      metode: metode ?? this.metode,
      mazhab: mazhab ?? this.mazhab,
      notifikasiAktif: notifikasiAktif ?? this.notifikasiAktif,
      lokasiDiperbaruiPada: lokasiDiperbaruiPada ?? this.lokasiDiperbaruiPada,
    );
  }

  Map<String, String> toMap() => {
    if (lintang != null) 'lintang': '$lintang',
    if (bujur != null) 'bujur': '$bujur',
    if (labelLokasi != null) 'label_lokasi': labelLokasi!,
    'metode': metode.kunci,
    'mazhab': mazhab.kunci,
    'notifikasi_aktif': notifikasiAktif ? '1' : '0',
    if (lokasiDiperbaruiPada != null)
      'lokasi_diperbarui_pada': lokasiDiperbaruiPada!.toIso8601String(),
  };

  factory Pengaturan.fromMap(Map<String, String> nilai) {
    final diperbarui = nilai['lokasi_diperbarui_pada'];
    return Pengaturan(
      lintang: double.tryParse(nilai['lintang'] ?? ''),
      bujur: double.tryParse(nilai['bujur'] ?? ''),
      labelLokasi: nilai['label_lokasi'],
      metode: MetodeSholat.dariKunci(nilai['metode']),
      mazhab: MazhabAshar.dariKunci(nilai['mazhab']),
      notifikasiAktif: (nilai['notifikasi_aktif'] ?? '1') == '1',
      lokasiDiperbaruiPada: diperbarui == null
          ? null
          : DateTime.tryParse(diperbarui),
    );
  }
}
