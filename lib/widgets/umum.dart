import 'package:flutter/material.dart';

/// Pembungkus kartu standar: sudut membulat, tanpa bayangan tebal, dengan
/// garis tepi setipis mungkin agar batasnya jelas tanpa ramai.
class KartuPanel extends StatelessWidget {
  const KartuPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.warna,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? warna;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Material(
      color: warna ?? Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: skema.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Judul bagian dengan aksi opsional di kanan.
class JudulSeksi extends StatelessWidget {
  const JudulSeksi({
    super.key,
    required this.judul,
    this.keterangan,
    this.aksi,
  });

  final String judul;
  final String? keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (keterangan != null) ...[
                const SizedBox(height: 2),
                Text(
                  keterangan!,
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (aksi != null) aksi!,
      ],
    );
  }
}

/// Kartu angka ringkas (stat tile): nilai besar, label, dan keterangan kecil.
class KartuAngka extends StatelessWidget {
  const KartuAngka({
    super.key,
    required this.nilai,
    required this.label,
    this.keterangan,
    this.ikon,
    this.warnaIkon,
  });

  final String nilai;
  final String label;
  final String? keterangan;
  final IconData? ikon;
  final Color? warnaIkon;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final warna = warnaIkon ?? skema.primary;

    return KartuPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (ikon != null) ...[
                Icon(ikon, size: 16, color: warna),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: teks.labelMedium?.copyWith(
                    color: skema.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nilai,
            style: teks.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          if (keterangan != null) ...[
            const SizedBox(height: 4),
            Text(
              keterangan!,
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lencana predikat: warna status selalu disertai ikon dan label.
class LencanaStatus extends StatelessWidget {
  const LencanaStatus({
    super.key,
    required this.label,
    required this.warna,
    required this.ikon,
    this.diAtasWarna = false,
  });

  final String label;
  final Color warna;
  final IconData ikon;

  /// Dipakai ketika lencana berdiri di atas permukaan berwarna (kartu hero).
  final bool diAtasWarna;

  @override
  Widget build(BuildContext context) {
    final latar = diAtasWarna
        ? Colors.white.withValues(alpha: 0.18)
        : warna.withValues(alpha: 0.14);
    final tinta = diAtasWarna ? Colors.white : warna;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: tinta),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tinta,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan saat belum ada data sama sekali.
class KeadaanKosong extends StatelessWidget {
  const KeadaanKosong({
    super.key,
    required this.ikon,
    required this.judul,
    required this.pesan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String pesan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    // Tanpa Center di sini, widget ini aman dipakai baik di dalam ListView
    // (tinggi tak terbatas) maupun di dalam Center/SliverFillRemaining.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: skema.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(ikon, size: 34, color: skema.primary),
          ),
          const SizedBox(height: 18),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: teks.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
          ),
          if (aksi != null) ...[const SizedBox(height: 22), aksi!],
        ],
      ),
    );
  }
}
