import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hasil penyimpanan berkas, untuk dijadikan pesan ke pengguna.
@immutable
class HasilSimpan {
  const HasilSimpan.tersimpan(this.lokasi) : dibatalkan = false;
  const HasilSimpan.dibatalkan() : lokasi = null, dibatalkan = true;

  /// Jalur berkas, atau null bila berkas diserahkan lewat lembar berbagi.
  final String? lokasi;
  final bool dibatalkan;

  String get pesan {
    if (dibatalkan) return 'Ekspor dibatalkan.';
    final tujuan = lokasi;
    return tujuan == null ? 'Berkas siap dibagikan.' : 'Tersimpan di $tujuan';
  }
}

/// Menyimpan dan membuka berkas dengan cara yang wajar di tiap platform.
///
/// Di ponsel tidak ada penjelajah berkas yang bisa diandalkan untuk menyimpan,
/// jadi berkas ditulis ke folder sementara lalu diserahkan ke lembar berbagi.
/// Di desktop dipakai dialog simpan biasa.
class BerkasService {
  const BerkasService._();

  static bool get _ponsel => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<HasilSimpan> simpanBiner({
    required String namaBerkas,
    required Uint8List isi,
    required String jenisMime,
    required String labelJenis,
    required String ekstensi,
  }) async {
    if (_ponsel) {
      final berkas = await _tulisSementara(namaBerkas, isi);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(berkas.path, mimeType: jenisMime)],
          subject: namaBerkas,
        ),
      );
      return const HasilSimpan.tersimpan(null);
    }

    final tujuan = await getSaveLocation(
      suggestedName: namaBerkas,
      acceptedTypeGroups: [
        XTypeGroup(label: labelJenis, extensions: [ekstensi]),
      ],
    );
    if (tujuan == null) return const HasilSimpan.dibatalkan();

    final berkas = File(tujuan.path);
    await berkas.writeAsBytes(isi, flush: true);
    return HasilSimpan.tersimpan(berkas.path);
  }

  static Future<HasilSimpan> simpanTeks({
    required String namaBerkas,
    required String isi,
    required String jenisMime,
    required String labelJenis,
    required String ekstensi,
  }) => simpanBiner(
    namaBerkas: namaBerkas,
    isi: Uint8List.fromList(utf8.encode(isi)),
    jenisMime: jenisMime,
    labelJenis: labelJenis,
    ekstensi: ekstensi,
  );

  /// Membuka berkas teks pilihan pengguna. Mengembalikan null bila dibatalkan.
  static Future<({String nama, String isi})?> bukaTeks({
    required String labelJenis,
    required List<String> ekstensi,
  }) async {
    final berkas = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: labelJenis,
          extensions: ekstensi,
          // Beberapa pengelola berkas Android tidak mengenali tipe MIME untuk
          // .sql, jadi penyaringnya dilonggarkan di sana.
          uniformTypeIdentifiers: const ['public.plain-text'],
        ),
      ],
    );
    if (berkas == null) return null;
    return (nama: berkas.name, isi: await berkas.readAsString());
  }

  static Future<File> _tulisSementara(String nama, Uint8List isi) async {
    final dir = await getTemporaryDirectory();
    final berkas = File(p.join(dir.path, nama));
    await berkas.writeAsBytes(isi, flush: true);
    return berkas;
  }

  /// Nama berkas bercap waktu, misalnya `catatan-amalan-20260919-1432.xlsx`.
  static String namaBercapWaktu(String awalan, String ekstensi) {
    final kini = DateTime.now();
    String dua(int n) => n.toString().padLeft(2, '0');
    return '$awalan-${kini.year}${dua(kini.month)}${dua(kini.day)}'
        '-${dua(kini.hour)}${dua(kini.minute)}.$ekstensi';
  }
}
