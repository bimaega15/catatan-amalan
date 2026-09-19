import 'package:flutter/material.dart';

/// Katalog ikon untuk amalan.
///
/// Ikon disimpan di database sebagai kunci teks (bukan code point) supaya
/// `--tree-shake-icons` tetap bekerja dan ikon selalu valid walau versi
/// Flutter berganti.
const Map<String, IconData> katalogIkonAmalan = {
  'subuh': Icons.wb_twilight,
  'matahari': Icons.wb_sunny_outlined,
  'senja': Icons.brightness_4_outlined,
  'bulan': Icons.nightlight_outlined,
  'bintang': Icons.star_outline,
  'masjid': Icons.mosque_outlined,
  'quran': Icons.menu_book_outlined,
  'buku': Icons.auto_stories_outlined,
  'tasbih': Icons.spa_outlined,
  'hati': Icons.favorite_outline,
  'doa': Icons.volunteer_activism_outlined,
  'sedekah': Icons.card_giftcard_outlined,
  'zakat': Icons.savings_outlined,
  'air': Icons.water_drop_outlined,
  'puasa': Icons.no_food_outlined,
  'makan': Icons.restaurant_outlined,
  'tidur': Icons.bedtime_outlined,
  'jalan': Icons.directions_walk_outlined,
  'olahraga': Icons.fitness_center_outlined,
  'keluarga': Icons.family_restroom_outlined,
  'orangtua': Icons.elderly_outlined,
  'ilmu': Icons.school_outlined,
  'tulis': Icons.edit_note_outlined,
  'suara': Icons.record_voice_over_outlined,
  'semangat': Icons.local_fire_department_outlined,
  'tumbuh': Icons.eco_outlined,
  'waktu': Icons.schedule_outlined,
  'ceklis': Icons.task_alt,
};

const String ikonBawaan = 'ceklis';

IconData ikonAmalan(String kunci) =>
    katalogIkonAmalan[kunci] ?? katalogIkonAmalan[ikonBawaan]!;
