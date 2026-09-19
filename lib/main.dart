import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'data/amalan_repository.dart';
import 'data/app_database.dart';
import 'data/cadangan_repository.dart';
import 'data/pengaturan_repository.dart';
import 'screens/kerangka_utama.dart';
import 'state/amalan_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('id');

  final db = await AppDatabase.instance.database;
  // Catatan dibaca sebelum frame pertama supaya aplikasi tidak dibuka dengan
  // kedipan pemuatan; isinya hanya beberapa ribu baris dari disk lokal.
  final kontroler = AmalanController(
    AmalanRepository(db),
    pengaturanRepo: PengaturanRepository(db),
    cadanganRepo: CadanganRepository(db),
  );
  await kontroler.muat();

  runApp(AplikasiCatatanAmalan(kontroler: kontroler));
}

/// Aplikasi pencatat amalan harian. Seluruh data tinggal di perangkat.
class AplikasiCatatanAmalan extends StatelessWidget {
  const AplikasiCatatanAmalan({super.key, required this.kontroler});

  final AmalanController kontroler;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AmalanController>.value(
      value: kontroler,
      child: MaterialApp(
        title: 'Catatan Amalan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.terang(),
        darkTheme: AppTheme.gelap(),
        locale: const Locale('id'),
        supportedLocales: const [Locale('id'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const KerangkaUtama(),
      ),
    );
  }
}
