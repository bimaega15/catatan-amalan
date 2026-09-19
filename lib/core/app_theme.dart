import 'package:flutter/material.dart';

/// Palet warna aplikasi. Nuansa hijau zamrud dipilih agar terasa tenang,
/// dengan aksen emas untuk menandai capaian.
class AppWarna {
  const AppWarna._();

  static const hijau = Color(0xFF0E8A6B);
  static const hijauTua = Color(0xFF075B47);
  static const emas = Color(0xFFC79226);
  static const merah = Color(0xFFC0432F);

  /// Gradasi yang dipakai pada kartu ringkasan di halaman beranda.
  static const gradasiHero = [Color(0xFF0E8A6B), Color(0xFF0B6B57)];

  /// Tangga warna untuk heatmap riwayat, dari "tidak ada amalan" ke "tuntas".
  static const tanggaHeatmap = [
    Color(0xFFE8EDEB),
    Color(0xFFBFE0D5),
    Color(0xFF8ECCB7),
    Color(0xFF4FAE8D),
    Color(0xFF0E8A6B),
  ];

  static const tanggaHeatmapGelap = [
    Color(0xFF26302D),
    Color(0xFF1F4A3E),
    Color(0xFF276B57),
    Color(0xFF2F8E71),
    Color(0xFF45C79E),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData terang() => _bangun(Brightness.light);

  static ThemeData gelap() => _bangun(Brightness.dark);

  static ThemeData _bangun(Brightness brightness) {
    final skema = ColorScheme.fromSeed(
      seedColor: AppWarna.hijau,
      brightness: brightness,
    );
    final gelap = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: gelap
          ? const Color(0xFF12171A)
          : const Color(0xFFF5F7F6),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: skema.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: gelap ? const Color(0xFF1B2226) : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: gelap ? const Color(0xFF232B30) : const Color(0xFFF1F4F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: skema.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: gelap ? const Color(0xFF1B2226) : Colors.white,
        indicatorColor: skema.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: skema.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: skema.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
