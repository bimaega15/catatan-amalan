import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/amalan_controller.dart';
import 'beranda_screen.dart';
import 'kelola_screen.dart';
import 'riwayat_screen.dart';
import 'statistik_screen.dart';

/// Kerangka aplikasi: empat halaman utama dengan bilah navigasi bawah.
class KerangkaUtama extends StatefulWidget {
  const KerangkaUtama({super.key});

  @override
  State<KerangkaUtama> createState() => _KerangkaUtamaState();
}

class _KerangkaUtamaState extends State<KerangkaUtama> {
  int _indeks = 0;

  @override
  Widget build(BuildContext context) {
    final kontroler = context.watch<AmalanController>();

    if (kontroler.memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (kontroler.galat != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 14),
                const Text(
                  'Gagal membuka catatan tersimpan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${kontroler.galat}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: kontroler.muat,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _indeks,
        children: const [
          BerandaScreen(),
          StatistikScreen(),
          RiwayatScreen(),
          KelolaScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indeks,
        onDestinationSelected: (nilai) => setState(() => _indeks = nilai),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl),
            label: 'Hari Ini',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Performa',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Amalan',
          ),
        ],
      ),
    );
  }
}
