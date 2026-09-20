import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/tanggal.dart';
import '../data/models/amalan.dart';
import 'jadwal_sholat_service.dart';

/// Pengingat amalan lewat notifikasi lokal.
///
/// Bunyinya berkas `beep3` — tiga bip pendek lalu berhenti — yang dipasang
/// pada saluran notifikasi Android. Karena suara saluran tidak bisa diubah
/// setelah dibuat, nama salurannya diberi akhiran versi: kalau suaranya
/// berganti, naikkan [_versiSaluran] agar saluran baru dibuat.
class NotifikasiService {
  NotifikasiService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _versiSaluran = 1;
  static const _idSaluran = 'pengingat_amalan_v$_versiSaluran';
  static const _namaSaluran = 'Pengingat Amalan';
  static const _namaBunyi = 'beep3';

  /// Jumlah hari ke depan yang dijadwalkan untuk amalan yang mengikuti jadwal
  /// sholat. Jamnya bergeser tiap hari, jadi tidak bisa memakai pengulangan
  /// harian bawaan sistem; jadwalnya dipasang ulang tiap aplikasi dibuka.
  static const hariDijadwalkan = 7;

  bool _siap = false;

  /// Notifikasi lokal hanya dipakai di ponsel. Di desktop fitur ini dilewati
  /// diam-diam supaya aplikasi tetap bisa dijalankan untuk pengembangan.
  static bool get didukung => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> siapkan() async {
    if (_siap || !didukung) return;

    tzdata.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      // Zona waktu tidak dikenali; biarkan memakai bawaan paket timezone.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        // Siluet putih berlatar transparan. Ikon peluncur tidak bisa dipakai
        // di bilah status: sejak Android 5 ikon notifikasi ditimpa satu warna,
        // sehingga ikon berwarna muncul sebagai kotak abu-abu.
        android: AndroidInitializationSettings('@drawable/ic_notifikasi'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _idSaluran,
            _namaSaluran,
            description: 'Pengingat amalan pada jam yang kamu tentukan.',
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound(_namaBunyi),
            playSound: true,
          ),
        );

    _siap = true;
  }

  /// Meminta izin notifikasi, dan di Android juga izin alarm tepat waktu.
  /// Mengembalikan true bila notifikasi boleh ditampilkan.
  Future<bool> mintaIzin() async {
    if (!didukung) return false;
    await siapkan();

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final boleh = await android?.requestNotificationsPermission() ?? false;
      // Tanpa izin ini pengingat bisa meleset beberapa menit pada Android 12+.
      await android?.requestExactAlarmsPermission();
      return boleh;
    }

    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> batalkanSemua() async {
    if (!didukung) return;
    await siapkan();
    await _plugin.cancelAll();
  }

  /// Memasang ulang seluruh pengingat.
  ///
  /// Dipanggil setiap daftar amalan, jadwal sholat, atau preferensi notifikasi
  /// berubah. Selalu membatalkan yang lama lebih dulu supaya tidak ada sisa
  /// jadwal dari amalan yang sudah dihapus.
  Future<void> jadwalkanUlang({
    required List<Amalan> amalan,
    required bool aktif,
    JadwalSholat? Function(DateTime tanggal)? jadwalSholat,
  }) async {
    if (!didukung) return;
    await siapkan();
    await _plugin.cancelAll();
    if (!aktif) return;

    final sekarang = DateTime.now();

    for (final a in amalan) {
      final id = a.id;
      if (id == null || a.diarsipkan || !a.adaPengingat) continue;

      if (a.sholat != null) {
        // Jam sholat berubah tiap hari, jadi tiap harinya dijadwalkan sendiri.
        for (var i = 0; i < hariDijadwalkan; i++) {
          final hari = tglSaja(sekarang).add(Duration(days: i));
          final waktu = JadwalSholatService.waktuPengingat(
            a,
            hari,
            jadwal: jadwalSholat?.call(hari),
          );
          if (waktu == null || !waktu.isAfter(sekarang)) continue;
          await _pasang(
            id: _idNotifikasi(id, i),
            amalan: a,
            waktu: waktu,
            harian: false,
          );
        }
        continue;
      }

      // Jam tetap: satu jadwal berulang harian, diurus oleh sistem.
      final menit = a.menitPengingat!;
      var waktu = DateTime(
        sekarang.year,
        sekarang.month,
        sekarang.day,
        menit ~/ 60,
        menit % 60,
      );
      if (!waktu.isAfter(sekarang)) {
        waktu = waktu.add(const Duration(days: 1));
      }
      await _pasang(
        id: _idNotifikasi(id, 0),
        amalan: a,
        waktu: waktu,
        harian: true,
      );
    }
  }

  /// Menampilkan notifikasi contoh sekarang juga, untuk menguji bunyinya.
  Future<void> ujiBunyi() async {
    if (!didukung) return;
    await siapkan();
    await _plugin.show(
      id: 0,
      title: 'Uji pengingat',
      body: 'Begini bunyi pengingat amalanmu nanti.',
      notificationDetails: _rincian(),
    );
  }

  Future<void> _pasang({
    required int id,
    required Amalan amalan,
    required DateTime waktu,
    required bool harian,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: amalan.nama,
      body: _pesan(amalan),
      scheduledDate: tz.TZDateTime.from(waktu, tz.local),
      notificationDetails: _rincian(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: harian ? DateTimeComponents.time : null,
      payload: '${amalan.id}',
    );
  }

  String _pesan(Amalan amalan) {
    if (amalan.sholat != null) {
      return 'Waktu ${amalan.sholat!.label} telah masuk.';
    }
    if (amalan.berupaHitungan) {
      return 'Saatnya ${amalan.nama} — target ${amalan.target} '
          '${amalan.satuan}.';
    }
    return 'Saatnya mengerjakan ${amalan.nama}.';
  }

  NotificationDetails _rincian() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _idSaluran,
      _namaSaluran,
      channelDescription: 'Pengingat amalan pada jam yang kamu tentukan.',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(_namaBunyi),
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      icon: '@drawable/ic_notifikasi',
      color: Color(0xFF0E8A6B),
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  /// Satu amalan memakai sepuluh slot id supaya penjadwalan beberapa hari ke
  /// depan tidak bertabrakan dengan amalan lain.
  static int _idNotifikasi(int amalanId, int offsetHari) =>
      amalanId * 10 + offsetHari;
}
