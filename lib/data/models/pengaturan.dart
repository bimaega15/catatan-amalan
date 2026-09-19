import 'package:flutter/foundation.dart';

/// Metode perhitungan jadwal sholat.
///
/// Yang membedakan metode adalah sudut matahari di bawah ufuk saat Subuh dan
/// Isya; sisanya (Dzuhur, Ashar, Maghrib) murni posisi matahari. Sudutnya
/// ditulis eksplisit di sini, bukan menumpang nama metode paket adhan, supaya
/// Kemenag bisa dihitung persis: paket adhan tidak menyediakannya.
enum MetodeSholat {
  kemenag('kemenag', 'Kemenag RI', 'Standar resmi Indonesia', 20, 20.0, 18.0),
  mwl('mwl', 'Muslim World League', 'Dipakai luas di dunia', 3, 18.0, 17.0),
  isna('isna', 'ISNA', 'Amerika Utara', 2, 15.0, 15.0),
  mesir(
    'egypt',
    'Mesir',
    'Egyptian General Authority of Survey',
    5,
    19.5,
    17.5,
  ),
  karachi(
    'karachi',
    'Karachi',
    'University of Islamic Sciences',
    1,
    18.0,
    18.0,
  ),
  ummAlQura(
    'umm_al_qura',
    'Umm al-Qura',
    'Makkah — Isya 90 menit setelah Maghrib',
    4,
    18.5,
    null,
    90,
  );

  const MetodeSholat(
    this.kunci,
    this.label,
    this.keterangan,
    this.kodeAladhan,
    this.sudutSubuh,
    this.sudutIsya, [
    this.jedaIsyaMenit = 0,
  ]);

  final String kunci;
  final String label;
  final String keterangan;

  /// Nomor metode yang sama pada API Aladhan.
  final int kodeAladhan;

  final double sudutSubuh;

  /// Null bila metodenya memakai [jedaIsyaMenit] alih-alih sudut.
  final double? sudutIsya;
  final int jedaIsyaMenit;

  static MetodeSholat dariKunci(String? kunci) {
    for (final metode in values) {
      if (metode.kunci == kunci) return metode;
    }
    return MetodeSholat.kemenag;
  }
}

/// Dari mana koordinat yang dipakai berasal.
enum SumberLokasi {
  /// Ditebak dari zona waktu perangkat; hanya ancar-ancar.
  perkiraan('Perkiraan dari zona waktu'),

  /// Dipilih sendiri dari daftar wilayah.
  wilayah('Wilayah pilihanmu'),

  /// Diambil dari GPS perangkat.
  gps('Lokasi perangkat');

  const SumberLokasi(this.label);

  final String label;

  static SumberLokasi dariNama(String? nama) {
    for (final sumber in values) {
      if (sumber.name == nama) return sumber;
    }
    return SumberLokasi.perkiraan;
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
    this.sumberLokasi = SumberLokasi.perkiraan,
    this.pakaiJadwalOnline = true,
  });

  final double? lintang;
  final double? bujur;

  /// Keterangan lokasi yang bisa dibaca manusia, misalnya koordinat singkat.
  final String? labelLokasi;

  final MetodeSholat metode;
  final MazhabAshar mazhab;
  final bool notifikasiAktif;
  final DateTime? lokasiDiperbaruiPada;
  final SumberLokasi sumberLokasi;

  /// Mengambil jadwal resmi dari API bila perangkat sedang daring. Kalau mati
  /// (atau sedang luring), jadwal dihitung sendiri di perangkat.
  final bool pakaiJadwalOnline;

  /// Lokasi masih tebakan dari zona waktu, bukan pilihan pengguna.
  bool get lokasiMasihPerkiraan =>
      adaLokasi && sumberLokasi == SumberLokasi.perkiraan;

  bool get adaLokasi => lintang != null && bujur != null;

  Pengaturan copyWith({
    double? lintang,
    double? bujur,
    String? labelLokasi,
    MetodeSholat? metode,
    MazhabAshar? mazhab,
    bool? notifikasiAktif,
    DateTime? lokasiDiperbaruiPada,
    SumberLokasi? sumberLokasi,
    bool? pakaiJadwalOnline,
    bool hapusLokasi = false,
  }) {
    if (hapusLokasi) {
      return Pengaturan(
        metode: metode ?? this.metode,
        mazhab: mazhab ?? this.mazhab,
        notifikasiAktif: notifikasiAktif ?? this.notifikasiAktif,
        pakaiJadwalOnline: pakaiJadwalOnline ?? this.pakaiJadwalOnline,
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
      sumberLokasi: sumberLokasi ?? this.sumberLokasi,
      pakaiJadwalOnline: pakaiJadwalOnline ?? this.pakaiJadwalOnline,
    );
  }

  Map<String, String> toMap() => {
    if (lintang != null) 'lintang': '$lintang',
    if (bujur != null) 'bujur': '$bujur',
    if (labelLokasi != null) 'label_lokasi': labelLokasi!,
    'metode': metode.kunci,
    'mazhab': mazhab.kunci,
    'notifikasi_aktif': notifikasiAktif ? '1' : '0',
    'sumber_lokasi': sumberLokasi.name,
    'jadwal_online': pakaiJadwalOnline ? '1' : '0',
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
      sumberLokasi: SumberLokasi.dariNama(nilai['sumber_lokasi']),
      pakaiJadwalOnline: (nilai['jadwal_online'] ?? '1') == '1',
      lokasiDiperbaruiPada: diperbarui == null
          ? null
          : DateTime.tryParse(diperbarui),
    );
  }
}
