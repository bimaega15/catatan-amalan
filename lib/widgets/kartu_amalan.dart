import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/viz_palette.dart';
import '../data/models/amalan.dart';

/// Baris satu amalan pada daftar harian.
///
/// Mengetuk badan kartu menambah capaian satu langkah; untuk amalan bertarget
/// satu, itu berarti langsung menandainya selesai.
class KartuAmalan extends StatelessWidget {
  const KartuAmalan({
    super.key,
    required this.amalan,
    required this.jumlah,
    required this.bolehMencatat,
    required this.onKetuk,
    required this.onKurangi,
    required this.onTahan,
  });

  final Amalan amalan;
  final int jumlah;
  final bool bolehMencatat;
  final VoidCallback onKetuk;
  final VoidCallback onKurangi;
  final VoidCallback onTahan;

  bool get _selesai => amalan.selesaiDengan(jumlah);

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final warna = VizPalet.kategori(context, amalan.kategori);
    final rasio = amalan.target == 0
        ? 0.0
        : math.min(1.0, jumlah / amalan.target);

    return Opacity(
      opacity: bolehMencatat ? 1 : 0.55,
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: bolehMencatat ? onKetuk : null,
          onLongPress: onTahan,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _selesai
                    ? skema.primary.withValues(alpha: 0.45)
                    : skema.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                _Lambang(warna: warna, ikon: amalan.ikonData),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amalan.nama,
                        style: teks.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _selesai
                              ? skema.onSurfaceVariant
                              : skema.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _Keterangan(
                        amalan: amalan,
                        jumlah: jumlah,
                        selesai: _selesai,
                      ),
                      if (amalan.berupaHitungan) ...[
                        const SizedBox(height: 8),
                        _BilahKemajuan(rasio: rasio, warna: warna),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (amalan.berupaHitungan && jumlah > 0 && bolehMencatat)
                  IconButton(
                    onPressed: onKurangi,
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    tooltip: 'Kurangi ${amalan.langkah}',
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                _TombolTanda(
                  selesai: _selesai,
                  aktif: bolehMencatat,
                  warna: warna,
                  hitungan: amalan.berupaHitungan,
                  onTekan: onKetuk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Lambang extends StatelessWidget {
  const _Lambang({required this.warna, required this.ikon});

  final Color warna;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(ikon, size: 21, color: warna),
    );
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({
    required this.amalan,
    required this.jumlah,
    required this.selesai,
  });

  final Amalan amalan;
  final int jumlah;
  final bool selesai;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    final label = amalan.berupaHitungan
        ? '$jumlah / ${amalan.target} ${amalan.satuan}'
        : (selesai
              ? 'Sudah dikerjakan'
              : (amalan.catatan?.isNotEmpty == true
                    ? amalan.catatan!
                    : amalan.kategori.label));

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: teks.bodySmall?.copyWith(
        color: selesai ? skema.primary : skema.onSurfaceVariant,
        fontWeight: selesai ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _BilahKemajuan extends StatelessWidget {
  const _BilahKemajuan({required this.rasio, required this.warna});

  final double rasio;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: rasio),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, nilai, _) => LinearProgressIndicator(
          value: nilai,
          minHeight: 4,
          backgroundColor: VizPalet.jejak(context),
          valueColor: AlwaysStoppedAnimation(warna),
        ),
      ),
    );
  }
}

class _TombolTanda extends StatelessWidget {
  const _TombolTanda({
    required this.selesai,
    required this.aktif,
    required this.warna,
    required this.hitungan,
    required this.onTekan,
  });

  final bool selesai;
  final bool aktif;
  final Color warna;
  final bool hitungan;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selesai,
      label: selesai ? 'Batalkan tanda selesai' : 'Tandai selesai',
      child: InkResponse(
        onTap: aktif ? onTekan : null,
        radius: 26,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selesai ? skema.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selesai
                    ? skema.primary
                    : skema.outlineVariant.withValues(alpha: 0.9),
                width: 1.6,
              ),
            ),
            child: Icon(
              selesai
                  ? Icons.check_rounded
                  : (hitungan ? Icons.add_rounded : Icons.check_rounded),
              size: 20,
              color: selesai ? skema.onPrimary : skema.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
