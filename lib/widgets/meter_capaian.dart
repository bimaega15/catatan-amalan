import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Meter berbentuk cincin: satu rasio terhadap satu batas.
///
/// Jejak dan busur memakai warna serumpun dengan opasitas berbeda, sehingga
/// terbaca sebagai satu skala, bukan dua kategori.
class MeterCapaian extends StatelessWidget {
  const MeterCapaian({
    super.key,
    required this.nilai,
    required this.warna,
    required this.warnaJejak,
    this.ukuran = 132,
    this.ketebalan = 10,
    this.isi,
  });

  /// Rasio 0..1.
  final double nilai;
  final Color warna;
  final Color warnaJejak;
  final double ukuran;
  final double ketebalan;
  final Widget? isi;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: nilai.clamp(0, 1)),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, animasi, child) => CustomPaint(
          painter: _PelukisMeter(
            nilai: animasi,
            warna: warna,
            warnaJejak: warnaJejak,
            ketebalan: ketebalan,
          ),
          child: child,
        ),
        child: Center(child: isi),
      ),
    );
  }
}

class _PelukisMeter extends CustomPainter {
  _PelukisMeter({
    required this.nilai,
    required this.warna,
    required this.warnaJejak,
    required this.ketebalan,
  });

  final double nilai;
  final Color warna;
  final Color warnaJejak;
  final double ketebalan;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - ketebalan) / 2;
    if (radius <= 0) return;

    final jejak = Paint()
      ..color = warnaJejak
      ..style = PaintingStyle.stroke
      ..strokeWidth = ketebalan
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(pusat, radius, jejak);

    if (nilai <= 0) return;

    final busur = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = ketebalan
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: pusat, radius: radius),
      -math.pi / 2,
      2 * math.pi * nilai,
      false,
      busur,
    );
  }

  @override
  bool shouldRepaint(_PelukisMeter oldDelegate) =>
      oldDelegate.nilai != nilai ||
      oldDelegate.warna != warna ||
      oldDelegate.warnaJejak != warnaJejak ||
      oldDelegate.ketebalan != ketebalan;
}
