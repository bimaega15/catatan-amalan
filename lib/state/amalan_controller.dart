import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/tanggal.dart';
import '../data/amalan_repository.dart';
import '../data/cadangan_repository.dart';
import '../data/models/amalan.dart';
import '../data/models/pengaturan.dart';
import '../data/models/statistik.dart';
import '../data/jadwal_cache_repository.dart';
import '../data/pengaturan_repository.dart';
import '../data/statistik_service.dart';
import '../data/wilayah_indonesia.dart';
import '../services/ekspor_excel_service.dart';
import '../services/jadwal_sholat_api.dart';
import '../services/jadwal_sholat_service.dart';
import '../services/notifikasi_service.dart';

/// Pilihan rentang pada halaman statistik.
enum PeriodeStatistik {
  tujuhHari('7 Hari', 7),
  tigaPuluhHari('30 Hari', 30),
  sembilanPuluhHari('90 Hari', 90);

  const PeriodeStatistik(this.label, this.hari);

  final String label;
  final int hari;
}

/// Penyimpan status aplikasi.
///
/// Seluruh catatan disimpan di memori sebagai peta tanggal -> amalan -> jumlah,
/// sehingga beranda, statistik, dan riwayat bisa dihitung seketika tanpa kueri
/// tambahan. Setiap perubahan diterapkan ke memori lebih dulu (agar tampilan
/// responsif) lalu ditulis ke database.
class AmalanController extends ChangeNotifier {
  AmalanController(
    this._repo, {
    required PengaturanRepository pengaturanRepo,
    required CadanganRepository cadanganRepo,
    required JadwalCacheRepository jadwalRepo,
    NotifikasiService? notifikasi,
    Duration? zonaPerangkat,
  }) : _pengaturanRepo = pengaturanRepo,
       _cadanganRepo = cadanganRepo,
       _jadwalRepo = jadwalRepo,
       _notifikasi = notifikasi ?? NotifikasiService(),
       _zonaPerangkat = zonaPerangkat ?? DateTime.now().timeZoneOffset;

  final AmalanRepository _repo;
  final PengaturanRepository _pengaturanRepo;
  final CadanganRepository _cadanganRepo;
  final JadwalCacheRepository _jadwalRepo;
  final NotifikasiService _notifikasi;

  /// Selisih zona waktu perangkat, dipakai menebak wilayah awal. Bisa disuntik
  /// agar pengujian tidak bergantung pada jam mesin penguji.
  final Duration _zonaPerangkat;

  bool _memuat = true;
  Object? _galat;
  List<Amalan> _amalan = const [];
  PetaCatatan _catatan = {};
  DateTime _tanggalAktif = hariIni();
  PeriodeStatistik _periode = PeriodeStatistik.tigaPuluhHari;
  DateTime _bulanRiwayat = DateTime(hariIni().year, hariIni().month);
  Pengaturan _pengaturan = const Pengaturan();
  bool _sedangAmbilLokasi = false;
  JadwalBulanan _jadwalResmi = {};
  bool _sedangSegarkanJadwal = false;
  String? _galatJadwal;

  bool get memuat => _memuat;
  Object? get galat => _galat;
  List<Amalan> get semuaAmalan => _amalan;
  DateTime get tanggalAktif => _tanggalAktif;
  PeriodeStatistik get periode => _periode;
  DateTime get bulanRiwayat => _bulanRiwayat;
  Pengaturan get pengaturan => _pengaturan;
  bool get sedangAmbilLokasi => _sedangAmbilLokasi;
  bool get sedangSegarkanJadwal => _sedangSegarkanJadwal;

  /// Pesan kegagalan pengambilan jadwal daring terakhir, bila ada. Sifatnya
  /// hanya pemberitahuan: jadwal tetap tampil dari hasil hitungan perangkat.
  String? get galatJadwal => _galatJadwal;

  /// Jadwal hari ini berasal dari API resmi, bukan hitungan perangkat.
  bool get jadwalResmiTersedia =>
      _jadwalResmi.containsKey(kunciTanggal(hariIni()));

  bool get notifikasiDidukung => NotifikasiService.didukung;

  List<Amalan> get amalanAktif =>
      _amalan.where((a) => !a.diarsipkan).toList(growable: false);

  List<Amalan> get amalanDiarsipkan =>
      _amalan.where((a) => a.diarsipkan).toList(growable: false);

  bool get kosong => amalanAktif.isEmpty;

  /// Hari yang sedang dilihat belum lewat, jadi masih boleh dicatat.
  bool get bolehMencatat => !_tanggalAktif.isAfter(hariIni());

  bool get sedangDiHariIni => tanggalSama(_tanggalAktif, hariIni());

  Future<void> muat() async {
    _memuat = true;
    _galat = null;
    notifyListeners();
    try {
      final amalan = await _repo.muatAmalan();
      final catatan = await _repo.muatSemuaCatatan();
      var pengaturan = await _pengaturanRepo.muat();
      // Tanpa lokasi, jadwal sholat tidak bisa dihitung sama sekali dan kartu
      // amalan tampil tanpa jam. Ditebak dulu dari zona waktu perangkat supaya
      // ada isinya sejak pertama dibuka; pengguna tetap diminta memilih
      // wilayahnya lewat ajakan di beranda.
      if (!pengaturan.adaLokasi) {
        final tebakan = tebakWilayahDariZona(_zonaPerangkat);
        if (tebakan != null) {
          pengaturan = pengaturan.copyWith(
            lintang: tebakan.lintang,
            bujur: tebakan.bujur,
            labelLokasi: tebakan.label,
            sumberLokasi: SumberLokasi.perkiraan,
          );
          await _pengaturanRepo.simpan(pengaturan);
        }
      }

      _amalan = amalan;
      _catatan = catatan;
      _pengaturan = pengaturan;
      _jadwalResmi = await _jadwalRepo.muat(
        JadwalCacheRepository.kunciLokasi(pengaturan),
      );
      unawaited(_siapkanPengingat());
      unawaited(segarkanJadwalOnline());
    } catch (e) {
      _galat = e;
    } finally {
      _memuat = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- navigasi

  void pilihTanggal(DateTime tanggal) {
    final hari = tglSaja(tanggal);
    if (tanggalSama(hari, _tanggalAktif)) return;
    _tanggalAktif = hari;
    notifyListeners();
  }

  void geserTanggal(int hari) =>
      pilihTanggal(_tanggalAktif.add(Duration(days: hari)));

  void kembaliKeHariIni() => pilihTanggal(hariIni());

  void pilihPeriode(PeriodeStatistik nilai) {
    if (nilai == _periode) return;
    _periode = nilai;
    notifyListeners();
  }

  void geserBulanRiwayat(int bulan) {
    _bulanRiwayat = DateTime(_bulanRiwayat.year, _bulanRiwayat.month + bulan);
    notifyListeners();
  }

  // -------------------------------------------------------------- pembacaan

  /// Amalan yang berlaku pada [tanggal] (bawaan: tanggal aktif).
  List<Amalan> amalanPada([DateTime? tanggal]) =>
      StatistikService.amalanBerlaku(_amalan, tanggal ?? _tanggalAktif);

  /// Amalan tanggal aktif, dikelompokkan menurut waktu pengerjaan.
  Map<WaktuAmalan, List<Amalan>> amalanPerWaktu([DateTime? tanggal]) {
    final grup = <WaktuAmalan, List<Amalan>>{};
    for (final a in amalanPada(tanggal)) {
      (grup[a.waktu] ??= <Amalan>[]).add(a);
    }
    // Urutkan kunci mengikuti urutan alami enum: pagi -> siang -> ... -> bebas.
    return Map.fromEntries(
      WaktuAmalan.values
          .where(grup.containsKey)
          .map((w) => MapEntry(w, grup[w]!)),
    );
  }

  int capaian(Amalan amalan, [DateTime? tanggal]) {
    final id = amalan.id;
    if (id == null) return 0;
    return _catatan[kunciTanggal(tanggal ?? _tanggalAktif)]?[id] ?? 0;
  }

  bool sudahSelesai(Amalan amalan, [DateTime? tanggal]) =>
      amalan.selesaiDengan(capaian(amalan, tanggal));

  RingkasanHarian ringkasan([DateTime? tanggal]) =>
      StatistikService.ringkasanHari(
        _amalan,
        _catatan,
        tanggal ?? _tanggalAktif,
      );

  int get streak => StatistikService.streakSaatIni(_amalan, _catatan);

  PerformaRentang performa([PeriodeStatistik? periode]) =>
      StatistikService.performa(
        _amalan,
        _catatan,
        rentangHariTerakhir((periode ?? _periode).hari),
      );

  List<RingkasanHarian> ringkasanPekanTerakhir() =>
      StatistikService.ringkasanRentang(
        _amalan,
        _catatan,
        rentangHariTerakhir(7),
      );

  List<KonsistensiAmalan> konsistensi([PeriodeStatistik? periode]) =>
      StatistikService.konsistensi(
        _amalan,
        _catatan,
        rentangHariTerakhir((periode ?? _periode).hari),
      );

  List<PorsiKategori> porsiKategori([PeriodeStatistik? periode]) =>
      StatistikService.porsiKategori(
        _amalan,
        _catatan,
        rentangHariTerakhir((periode ?? _periode).hari),
      );

  /// Ringkasan tiap hari pada bulan yang sedang dilihat di halaman riwayat.
  List<RingkasanHarian> ringkasanBulan([DateTime? bulan]) {
    final acuan = bulan ?? _bulanRiwayat;
    final jumlahHari = DateTime(acuan.year, acuan.month + 1, 0).day;
    final hari = List<DateTime>.generate(
      jumlahHari,
      (i) => DateTime(acuan.year, acuan.month, i + 1),
    );
    return StatistikService.ringkasanRentang(_amalan, _catatan, hari);
  }

  // ------------------------------------------------------------- pencatatan

  /// Menaikkan capaian satu langkah. Untuk amalan target tunggal ini berarti
  /// menandai selesai; jika sudah penuh, capaian dikembalikan ke nol.
  Future<void> ketukAmalan(Amalan amalan, [DateTime? tanggal]) async {
    final sekarang = capaian(amalan, tanggal);
    if (sekarang >= amalan.target) {
      await setCapaian(amalan, 0, tanggal);
      return;
    }
    final tambahan = amalan.berupaHitungan ? amalan.langkah : 1;
    await setCapaian(
      amalan,
      math.min(amalan.target, sekarang + tambahan),
      tanggal,
    );
  }

  Future<void> kurangiAmalan(Amalan amalan, [DateTime? tanggal]) async {
    final sekarang = capaian(amalan, tanggal);
    if (sekarang == 0) return;
    final berikutnya = amalan.berupaHitungan
        ? math.max(0, sekarang - amalan.langkah)
        : 0;
    await setCapaian(amalan, berikutnya, tanggal);
  }

  Future<void> tuntaskanAmalan(Amalan amalan, [DateTime? tanggal]) =>
      setCapaian(amalan, amalan.target, tanggal);

  Future<void> setCapaian(
    Amalan amalan,
    int jumlah, [
    DateTime? tanggal,
  ]) async {
    final id = amalan.id;
    if (id == null) return;
    final hari = tglSaja(tanggal ?? _tanggalAktif);
    if (hari.isAfter(hariIni())) return;

    final nilai = jumlah.clamp(0, amalan.target);
    _tulisCache(id, hari, nilai);
    notifyListeners();

    await _repo.simpanCapaian(amalanId: id, tanggal: hari, jumlah: nilai);
  }

  /// Menandai seluruh amalan pada [tanggal] sebagai selesai.
  Future<void> tuntaskanSemua([DateTime? tanggal]) async {
    final hari = tglSaja(tanggal ?? _tanggalAktif);
    if (hari.isAfter(hariIni())) return;

    final daftar = amalanPada(hari);
    for (final a in daftar) {
      final id = a.id;
      if (id == null) continue;
      _tulisCache(id, hari, a.target);
    }
    notifyListeners();

    for (final a in daftar) {
      final id = a.id;
      if (id == null) continue;
      await _repo.simpanCapaian(amalanId: id, tanggal: hari, jumlah: a.target);
    }
  }

  Future<void> kosongkanHari([DateTime? tanggal]) async {
    final hari = tglSaja(tanggal ?? _tanggalAktif);
    _catatan.remove(kunciTanggal(hari));
    notifyListeners();
    await _repo.kosongkanHari(hari);
  }

  void _tulisCache(int amalanId, DateTime tanggal, int jumlah) {
    final kunci = kunciTanggal(tanggal);
    if (jumlah <= 0) {
      final hari = _catatan[kunci];
      if (hari == null) return;
      hari.remove(amalanId);
      if (hari.isEmpty) _catatan.remove(kunci);
      return;
    }
    (_catatan[kunci] ??= <int, int>{})[amalanId] = jumlah;
  }

  // ------------------------------------------------ jadwal sholat & lokasi

  /// Ada amalan yang bergantung jadwal sholat, sementara wilayahnya belum
  /// dipilih sendiri — entah kosong atau masih tebakan dari zona waktu.
  bool get butuhLokasi =>
      (!_pengaturan.adaLokasi || _pengaturan.lokasiMasihPerkiraan) &&
      _amalan.any((a) => !a.diarsipkan && a.sholat != null);

  /// Jadwal sholat untuk [tanggal]; null bila lokasi belum pernah diambil.
  ///
  /// Mendahulukan jadwal resmi hasil unduhan; kalau harinya belum terunduh
  /// (atau fiturnya dimatikan), dipakai hitungan di perangkat yang selisihnya
  /// hanya hitungan menit.
  JadwalSholat? jadwalSholat([DateTime? tanggal]) {
    final hari = tglSaja(tanggal ?? _tanggalAktif);
    final resmi = _jadwalResmi[kunciTanggal(hari)];
    if (resmi != null) {
      return JadwalSholat(tanggal: hari, waktu: resmi, resmi: true);
    }
    return JadwalSholatService.hitung(_pengaturan, hari);
  }

  /// Jam pengingat efektif sebuah amalan pada [tanggal].
  DateTime? waktuPengingat(Amalan amalan, [DateTime? tanggal]) {
    final hari = tanggal ?? _tanggalAktif;
    return JadwalSholatService.waktuPengingat(
      amalan,
      hari,
      jadwal: jadwalSholat(hari),
    );
  }

  /// Mengambil koordinat perangkat lalu menghitung ulang jadwal sholat.
  ///
  /// Melempar [LokasiException] dengan pesan siap tampil bila gagal.
  Future<void> perbaruiLokasi() async {
    if (_sedangAmbilLokasi) return;
    _sedangAmbilLokasi = true;
    notifyListeners();
    try {
      final posisi = await JadwalSholatService.ambilLokasi();
      await _simpanPengaturan(
        _pengaturan.copyWith(
          lintang: posisi.latitude,
          bujur: posisi.longitude,
          labelLokasi: JadwalSholatService.labelKoordinat(
            posisi.latitude,
            posisi.longitude,
          ),
          sumberLokasi: SumberLokasi.gps,
          lokasiDiperbaruiPada: DateTime.now(),
        ),
      );
    } finally {
      _sedangAmbilLokasi = false;
      notifyListeners();
    }
  }

  /// Memakai wilayah pilihan pengguna sebagai acuan jadwal sholat.
  Future<void> pilihWilayah(Wilayah wilayah) => _simpanPengaturan(
    _pengaturan.copyWith(
      lintang: wilayah.lintang,
      bujur: wilayah.bujur,
      labelLokasi: wilayah.label,
      sumberLokasi: SumberLokasi.wilayah,
      lokasiDiperbaruiPada: DateTime.now(),
    ),
  );

  Future<void> setJadwalOnline(bool aktif) =>
      _simpanPengaturan(_pengaturan.copyWith(pakaiJadwalOnline: aktif));

  Future<void> hapusLokasi() =>
      _simpanPengaturan(_pengaturan.copyWith(hapusLokasi: true));

  Future<void> pilihMetodeSholat(MetodeSholat metode) =>
      _simpanPengaturan(_pengaturan.copyWith(metode: metode));

  Future<void> pilihMazhab(MazhabAshar mazhab) =>
      _simpanPengaturan(_pengaturan.copyWith(mazhab: mazhab));

  Future<void> setNotifikasi(bool aktif) async {
    if (aktif && !await _notifikasi.mintaIzin()) {
      // Izin ditolak: biarkan sakelar kembali mati agar tidak menjanjikan
      // pengingat yang tidak akan pernah muncul.
      return;
    }
    await _simpanPengaturan(_pengaturan.copyWith(notifikasiAktif: aktif));
  }

  Future<void> ujiBunyiNotifikasi() => _notifikasi.ujiBunyi();

  Future<void> _simpanPengaturan(Pengaturan baru) async {
    final lokasiBerubah =
        JadwalCacheRepository.kunciLokasi(baru) !=
        JadwalCacheRepository.kunciLokasi(_pengaturan);

    _pengaturan = baru;
    // Jadwal unduhan terikat pada koordinat, metode, dan mazhab tertentu, jadi
    // begitu salah satunya berubah isinya tidak boleh dipakai lagi.
    if (lokasiBerubah) _jadwalResmi = {};
    notifyListeners();

    await _pengaturanRepo.simpan(baru);
    await _jadwalkanUlang();
    if (lokasiBerubah) unawaited(segarkanJadwalOnline());
  }

  /// Mengunduh jadwal resmi bulan ini dan bulan depan.
  ///
  /// Dua bulan sekaligus supaya pengingat tujuh hari ke depan tetap dapat
  /// jadwal walau hari ini jatuh di akhir bulan. Kegagalan tidak dianggap
  /// fatal: aplikasi kembali memakai hitungan di perangkat.
  Future<void> segarkanJadwalOnline({bool paksa = false}) async {
    if (_sedangSegarkanJadwal) return;
    if (!_pengaturan.pakaiJadwalOnline && !paksa) return;
    if (!_pengaturan.adaLokasi) return;

    _sedangSegarkanJadwal = true;
    _galatJadwal = null;
    notifyListeners();

    final lokasi = JadwalCacheRepository.kunciLokasi(_pengaturan);
    try {
      final ini = hariIni();
      final bulanan = <String, Map<SholatWajib, DateTime>>{};
      for (final geser in [0, 1]) {
        final bulan = DateTime(ini.year, ini.month + geser);
        bulanan.addAll(
          await JadwalSholatApi.ambilBulan(
            lintang: _pengaturan.lintang!,
            bujur: _pengaturan.bujur!,
            metode: _pengaturan.metode,
            mazhab: _pengaturan.mazhab,
            tahun: bulan.year,
            bulan: bulan.month,
          ),
        );
      }

      await _jadwalRepo.rapikan(lokasi);
      await _jadwalRepo.simpan(lokasi, bulanan);
      _jadwalResmi = bulanan;
      await _jadwalkanUlang();
    } on JadwalApiException catch (e) {
      _galatJadwal = e.pesan;
    } catch (e) {
      _galatJadwal = 'Jadwal gagal diperbarui: $e';
    } finally {
      _sedangSegarkanJadwal = false;
      notifyListeners();
    }
  }

  /// Menyiapkan pengingat saat aplikasi dibuka.
  ///
  /// Izin diminta lebih dulu bila pengingat menyala: tanpa itu, di Android 13+
  /// notifikasi dijadwalkan tetapi tidak pernah muncul. Sistem hanya
  /// menampilkan dialognya sekali, jadi aman dipanggil tiap kali membuka.
  Future<void> _siapkanPengingat() async {
    if (_pengaturan.notifikasiAktif) await _notifikasi.mintaIzin();
    await _jadwalkanUlang();
  }

  Future<void> _jadwalkanUlang() => _notifikasi.jadwalkanUlang(
    amalan: _amalan,
    aktif: _pengaturan.notifikasiAktif,
    jadwalSholat: jadwalSholat,
  );

  // ------------------------------------------------------- ekspor & impor

  /// Menyusun berkas Excel dari seluruh catatan.
  Uint8List susunExcel() =>
      EksporExcelService.susun(amalan: _amalan, catatan: _catatan);

  /// Menyusun cadangan lengkap dalam bentuk SQL.
  Future<String> susunSql() => _cadanganRepo.keSql();

  /// Memulihkan data dari berkas SQL hasil ekspor. Mengembalikan jumlah baris
  /// yang dipulihkan.
  Future<int> pulihkanDariSql(String isi) async {
    final jumlah = await _cadanganRepo.dariSql(isi);
    await muat();
    return jumlah;
  }

  // ------------------------------------------------------------ kelola amalan

  Future<void> tambahAmalan(Amalan amalan) async {
    final tersimpan = await _repo.tambahAmalan(amalan);
    _amalan = [..._amalan, tersimpan];
    notifyListeners();
    await _jadwalkanUlang();
  }

  Future<void> perbaruiAmalan(Amalan amalan) async {
    await _repo.perbaruiAmalan(amalan);
    _amalan = _amalan.map((a) => a.id == amalan.id ? amalan : a).toList();
    notifyListeners();
    await _jadwalkanUlang();
  }

  Future<void> hapusAmalan(Amalan amalan) async {
    final id = amalan.id;
    if (id == null) return;
    await _repo.hapusAmalan(id);
    _amalan = _amalan.where((a) => a.id != id).toList();
    for (final hari in _catatan.values) {
      hari.remove(id);
    }
    _catatan.removeWhere((_, hari) => hari.isEmpty);
    notifyListeners();
    await _jadwalkanUlang();
  }

  Future<void> arsipkanAmalan(Amalan amalan) async {
    final id = amalan.id;
    if (id == null) return;
    final sejak = hariIni();
    await _repo.arsipkanAmalan(id, sejak: sejak);
    _amalan = _amalan
        .map((a) => a.id == id ? a.copyWith(diarsipkanPada: sejak) : a)
        .toList();
    notifyListeners();
    await _jadwalkanUlang();
  }

  Future<void> aktifkanAmalan(Amalan amalan) async {
    final id = amalan.id;
    if (id == null) return;
    await _repo.aktifkanAmalan(id);
    _amalan = _amalan
        .map((a) => a.id == id ? a.copyWith(hapusArsip: true) : a)
        .toList();
    notifyListeners();
    await _jadwalkanUlang();
  }

  /// Memindahkan amalan aktif dari posisi [dari] ke [ke] pada daftar kelola.
  Future<void> pindahkanAmalan(int dari, int ke) async {
    final daftar = amalanAktif.toList();
    if (dari < 0 || dari >= daftar.length) return;
    final tujuan = ke > dari ? ke - 1 : ke;
    final item = daftar.removeAt(dari);
    daftar.insert(tujuan.clamp(0, daftar.length), item);

    final urutanBaru = <int, int>{};
    for (var i = 0; i < daftar.length; i++) {
      final id = daftar[i].id;
      if (id != null) urutanBaru[id] = i;
    }

    _amalan =
        _amalan
            .map(
              (a) => urutanBaru.containsKey(a.id)
                  ? a.copyWith(urutan: urutanBaru[a.id])
                  : a,
            )
            .toList()
          ..sort((a, b) => a.urutan.compareTo(b.urutan));
    notifyListeners();

    await _repo.simpanUrutan(daftar.map((a) => a.id).whereType<int>().toList());
  }
}
