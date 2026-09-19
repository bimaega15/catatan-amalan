# Catatan Amalan

Aplikasi Flutter untuk mencatat amalan harian — dzikir pagi, sholat, tilawah,
sedekah, dan apa pun yang ingin dijaga. Semua data tersimpan di perangkat lewat
SQLite; tidak ada akun, server, atau sinkronisasi.

## Fitur

- **Daftar harian** yang dikelompokkan menurut waktu (pagi, siang, sore, malam,
  kapan saja). Ketuk untuk menandai selesai.
- **Amalan berupa hitungan**, misalnya istighfar 100 kali atau tilawah 5
  halaman. Capaian sebagian ikut dihitung.
- **Amalan buatan sendiri**: nama, kategori, waktu, target, satuan, ikon, dan
  catatan. Urutannya bisa digeser sesuka hati.
- **Mengisi hari yang terlewat** lewat deretan tanggal atau pemilih tanggal.
- **Halaman performa**: rata-rata capaian, predikat, hari beruntun, grafik
  capaian harian, tren, porsi per kategori, dan konsistensi tiap amalan.
- **Riwayat bulanan** sebagai kalender berwarna, bisa dibuka per hari.
- **Arsip**: amalan yang dihentikan berhenti dihitung sejak tanggal
  pengarsipan, tanpa mengubah riwayat lama.

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
| `lib/state/` | `AmalanController`, satu-satunya sumber status aplikasi |
| `lib/screens/` | empat halaman utama dan formulir amalan |
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

## Pengujian

```bash
flutter test
```

Mencakup perhitungan statistik (murni), repository di atas SQLite dalam memori,
dan uji rakitan yang menelusuri keempat halaman.

## Catatan dependensi

`sqflite_common_ffi` sengaja ditahan di bawah versi 2.4. Versi tersebut menarik
`sqlite3` 3.x yang membangun SQLite lewat *hooks* (native assets); hooks belum
dijalankan oleh `flutter build windows`, sehingga aplikasi gagal memuat
`sqlite3.dll`. Pasangan `sqlite3` 2.x + `sqlite3_flutter_libs` 0.5.x membundel
DLL tersebut lewat plugin, tanpa flag percobaan.
