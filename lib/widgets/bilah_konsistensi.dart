import 'package:flutter/material.dart';

import '../core/viz_palette.dart';
import '../data/models/statistik.dart';

/// Bilah mendatar konsistensi tiap amalan.
///
/// Membandingkan besaran, jadi warnanya satu tangga (makin konsisten makin
/// pekat) dan setiap baris memakai label langsung, bukan legenda.
class BilahKonsistensi extends StatelessWidget {
  const BilahKonsistensi({
    super.key,
    required this.daftar,
    this.batas = 6,
    this.onKetuk,
  });

  final List<KonsistensiAmalan> daftar;

  /// Jumlah baris yang ditampilkan sebelum sisanya disembunyikan.
  final int batas;
  final ValueChanged<KonsistensiAmalan>? onKetuk;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    if (daftar.isEmpty) {
      return Text(
        'Belum ada amalan yang bisa diukur pada periode ini.',
        style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
      );
    }

    final tampil = daftar.take(batas).toList();

    return Column(
      children: [
        for (var i = 0; i < tampil.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _Baris(data: tampil[i], onKetuk: onKetuk),
        ],
        if (daftar.length > batas) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '+${daftar.length - batas} amalan lainnya',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.data, this.onKetuk});

  final KonsistensiAmalan data;
  final ValueChanged<KonsistensiAmalan>? onKetuk;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final warna = VizPalet.selCapaian(context, data.rasioSelesai);

    return InkWell(
      onTap: onKetuk == null ? null : () => onKetuk!(data),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.amalan.ikonData,
                size: 15,
                color: VizPalet.kategori(context, data.amalan.kategori),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  data.amalan.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${data.hariSelesai}/${data.hariBerlaku} hari',
                style: teks.labelSmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  '${data.persenSelesai}%',
                  textAlign: TextAlign.right,
                  style: teks.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: data.rasioSelesai),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, nilai, _) => LinearProgressIndicator(
                value: nilai,
                minHeight: 6,
                backgroundColor: VizPalet.jejak(context),
                valueColor: AlwaysStoppedAnimation(warna),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
