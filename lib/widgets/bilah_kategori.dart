import 'package:flutter/material.dart';

import '../core/viz_palette.dart';
import '../data/models/statistik.dart';

/// Porsi amalan tuntas per kategori sebagai satu bilah bertumpuk mendatar.
///
/// Bentuk ini dipilih ketimbang diagram lingkaran: nilai yang berdekatan tetap
/// mudah dibandingkan, nama kategori bisa ditulis penuh, dan setiap ruas punya
/// label langsung sehingga identitasnya tidak bergantung pada warna saja.
class BilahKategori extends StatelessWidget {
  const BilahKategori({super.key, required this.porsi});

  final List<PorsiKategori> porsi;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    final total = porsi.fold<int>(0, (jml, p) => jml + p.jumlahSelesai);
    if (total == 0) {
      return Text(
        'Belum ada amalan yang tuntas pada periode ini.',
        style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ruas dipisahkan jarak 2px berwarna permukaan, bukan garis tepi.
        SizedBox(
          height: 14,
          child: Row(
            // Ruas tidak punya anak, jadi tanpa stretch tingginya nol dan
            // bilahnya tidak kelihatan sama sekali.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < porsi.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: porsi[i].jumlahSelesai,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: VizPalet.kategori(context, porsi[i].kategori),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(i == 0 ? 7 : 2),
                        right: Radius.circular(i == porsi.length - 1 ? 7 : 2),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final p in porsi)
              _Keterangan(
                kategori: p,
                persen: (p.jumlahSelesai / total * 100).round(),
              ),
          ],
        ),
      ],
    );
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({required this.kategori, required this.persen});

  final PorsiKategori kategori;
  final int persen;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: VizPalet.kategori(context, kategori.kategori),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          kategori.kategori.label,
          style: teks.bodySmall?.copyWith(color: skema.onSurface),
        ),
        const SizedBox(width: 5),
        Text(
          '$persen%',
          style: teks.bodySmall?.copyWith(
            color: skema.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
