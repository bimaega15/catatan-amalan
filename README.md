# Catatan Amalan

Aplikasi Flutter untuk mencatat amalan harian — dzikir pagi, sholat, tilawah,
sedekah, dan apa pun yang ingin dijaga. Semua data tersimpan di perangkat lewat
SQLite; tidak ada akun, server, atau sinkronisasi.

## Fitur

- **Daftar harian** yang dikelompokkan menurut waktu (pagi, siang, sore, malam,
  kapan saja). Ketuk untuk menandai selesai.
- **Amalan berupa hitungan**, misalnya istighfar 100 kali atau tilawah 5
  halaman. Capaian sebagian ikut dihitung.
- **Amalan buatan sendiri**: nama, kategori, waktu, target, satuan, ikon, jam
  pengingat, dan catatan. Urutannya bisa digeser sesuka hati.
- **Jadwal sholat otomatis** menurut wilayah pengguna. Lima sholat fardhu
  memakai jam yang dihitung ulang tiap hari; amalan lain boleh memakai jam
  tetap atau tanpa jam sama sekali.
- **Pengingat** berupa notifikasi lokal yang berbunyi tiga bip pendek lalu
  berhenti.
- **Mengisi hari yang terlewat** lewat deretan tanggal atau pemilih tanggal.
- **Halaman performa**: rata-rata capaian, predikat, hari beruntun, grafik
  capaian harian, tren, porsi per kategori, dan konsistensi tiap amalan.
- **Riwayat bulanan** sebagai kalender berwarna, bisa dibuka per hari.
- **Arsip**: amalan yang dihentikan berhenti dihitung sejak tanggal
  pengarsipan, tanpa mengubah riwayat lama.
- **Ekspor Excel** (daftar amalan, catatan harian, rekap), **ekspor cadangan
  SQL**, dan **impor kembali dari berkas SQL**.

## Cara menjalankan

```bash
flutter pub get
flutter run            # Android/iOS
flutter run -d windows # desktop
```

## Struktur kode

| Folder | Isi |
| --- | --- |
| `lib/core/` | tema, katalog ikon, utilitas tanggal, palet grafik |
| `lib/data/` | model, skema SQLite, repository, perhitungan statistik |
| `lib/services/` | jadwal sholat, notifikasi, ekspor Excel, berkas |
| `lib/state/` | `AmalanController`, satu-satunya sumber status aplikasi |
| `lib/screens/` | lima halaman dan formulir amalan |
| `lib/widgets/` | kartu, meter, grafik, kalender |

Catatan harian dimuat sekali ke memori sebagai peta
`tanggal -> amalan -> jumlah`, sehingga beranda, statistik, dan riwayat bisa
dihitung tanpa kueri tambahan. Setiap perubahan ditulis ke memori lebih dulu
agar tampilan responsif, lalu disimpan ke database.

### Cara capaian dihitung

Setiap amalan berbobot sama, dan capaian sebagian tetap dihitung: mengerjakan
50 dari 100 istighfar bernilai setengah untuk amalan itu. Rumus ini sengaja
dipilih ketimbang membagi total satuan, karena satu amalan bertarget 100 akan
menenggelamkan sebelas amalan bertarget 1. Sebuah hari dihitung menjaga
runtutan (*streak*) bila capaiannya minimal 80%.

### Jadwal sholat

Ada tiga cara menentukan wilayah acuan, dari yang paling ringan:

1. **Tebakan zona waktu.** Saat pertama dibuka, aplikasi memilih Jakarta,
   Makassar, atau Jayapura menurut selisih zona waktu perangkat — supaya jam
   sholat langsung tampil tanpa pengguna melakukan apa pun. Statusnya ditandai
   jujur sebagai perkiraan, lengkap dengan ajakan memilih kota.
2. **Pilih kota** dari daftar 74 kota yang mencakup seluruh 38 provinsi
   (`lib/data/wilayah_indonesia.dart`). Tanpa GPS, tanpa internet.
3. **Lokasi perangkat** lewat `geolocator`, untuk yang ingin persis.

Jamnya sendiri berasal dari dua sumber:

- **Daring:** jadwal resmi diambil dari API Aladhan memakai metode 20
  (Kementerian Agama RI), sebulan penuh sekali permintaan, lalu disimpan ke
  tabel `jadwal_sholat`. Cukup dua permintaan (bulan ini dan bulan depan)
  untuk menutupi seluruh penjadwalan pengingat.
- **Luring:** dihitung di perangkat dengan paket `adhan`. Sudut Subuh dan Isya
  ditulis eksplisit di `MetodeSholat`, bukan menumpang nama metode bawaan
  paket, karena Kemenag (Subuh 20°, Isya 18°) tidak tersedia di sana. Ada tes
  yang membandingkan hasil hitungan ini dengan angka resmi Aladhan dan gagal
  bila selisihnya lebih dari dua menit.

Koordinat tidak pernah dikirim ke mana pun selain ke API jadwal, dan itu pun
bisa dimatikan lewat sakelar "Ambil jadwal resmi saat daring". Baris cache
diberi label koordinat, metode, dan mazhab, jadi begitu salah satunya berubah
jadwal lama otomatis tidak terpakai.

### Pengingat

Bunyinya `android/app/src/main/res/raw/beep3.wav`, dibangkitkan sebagai tiga
nada 880 Hz masing-masing 140 ms lalu berhenti. Suara sebuah saluran notifikasi
Android tidak bisa diubah setelah saluran dibuat, jadi id salurannya
bernomor versi (`pengingat_amalan_v1`); kalau bunyinya diganti, naikkan
`_versiSaluran` di `lib/services/notifikasi_service.dart` agar saluran baru
dibuat.

Dua hal yang perlu diketahui:

- **Amalan berjam tetap** dijadwalkan sekali sebagai pengulangan harian yang
  diurus sistem. **Amalan yang mengikuti jadwal sholat** jamnya bergeser tiap
  hari, jadi dijadwalkan tujuh hari ke depan dan dipasang ulang setiap aplikasi
  dibuka. Kalau aplikasi tidak dibuka lebih dari sepekan, pengingat sholat
  berhenti sampai aplikasi dibuka lagi.
- **iOS** belum memakai bunyi tiga bip: berkas suaranya harus didaftarkan ke
  bundel lewat Xcode. Sebelum itu, iOS memakai bunyi notifikasi bawaan.

### Ekspor dan impor

Ekspor SQL menghasilkan berkas teks biasa berisi `CREATE TABLE` dan `INSERT`,
jadi bisa dibaca dan dipakai alat lain. Saat mengimpor, hanya pernyataan
`INSERT` ke tabel yang dikenal yang dijalankan — struktur tabel tetap milik
aplikasi, sehingga berkas dari versi lama tetap bisa dipulihkan dan berkas
asing tidak bisa menjalankan perintah sembarangan. Seluruh impor berjalan dalam
satu transaksi: bila ada satu baris yang gagal, data lama tetap utuh.

Di ponsel, berkas hasil ekspor diserahkan ke lembar berbagi; di desktop dipakai
dialog simpan biasa.

## Pengujian

```bash
flutter test
```

Mencakup perhitungan statistik dan jadwal sholat (murni), repository serta
migrasi skema di atas SQLite, ekspor Excel, ekspor/impor SQL, dan uji rakitan
yang menelusuri seluruh halaman.

## Catatan platform

**Android.** Proyek memakai AGP 8.11.1, Gradle 8.13, `compileSdk` 36, dan
`minSdk` 24 — semuanya syarat `flutter_local_notifications` 22. Desugaring
pustaka inti dinyalakan agar penjadwalan tetap bekerja di Android lama.
`AndroidManifest.xml` memuat izin notifikasi, alarm tepat waktu, lokasi, serta
penerima yang memasang ulang jadwal setelah perangkat dinyalakan ulang.

**Desktop.** Notifikasi dilewati diam-diam (fitur ini memang hanya untuk
ponsel), sedangkan sisanya berjalan penuh sehingga aplikasi tetap enak dipakai
untuk pengembangan.

**Dependensi SQLite.** `sqflite_common_ffi` sengaja ditahan di bawah versi 2.4.
Versi tersebut menarik `sqlite3` 3.x yang membangun SQLite lewat *hooks*
(native assets); hooks belum dijalankan oleh `flutter build windows`, sehingga
aplikasi gagal memuat `sqlite3.dll`. Pasangan `sqlite3` 2.x +
`sqlite3_flutter_libs` 0.5.x membundel DLL tersebut lewat plugin, tanpa flag
percobaan.
