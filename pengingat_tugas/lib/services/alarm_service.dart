import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task_model.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();

  static AudioPlayer? _audioPlayer;
  static bool _initialized = false;
  static Function(String)? onAlarmTriggered;

  // Channel dasar v9: SETIAP kombinasi fitur mendapat channel ID unik sendiri.
  // PENTING: memakai satu channel untuk semua kombinasi adalah bug klasik —
  // pengaturan channel Android TIDAK BISA diubah setelah pertama kali dibuat,
  // sehingga fallback yang hanya mengganti atribut suara tetap membaca
  // konfigurasi channel lama (alarm jadi tidak berbunyi sama sekali).
  static const String _baseChannelId = 'alarm_channel_v9';

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      debugPrint('[AlarmService] Timezone diatur ke: ${tzInfo.identifier}');
    } catch (e) {
      debugPrint('[AlarmService] Gagal mendapatkan timezone lokal, fallback ke Asia/Jakarta: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
    } catch (e) {
      debugPrint('[AlarmService] Gagal inisialisasi plugin notifikasi: $e');
    }

    try {
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
    } catch (_) {}

    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (_) {}

    try {
      final NotificationAppLaunchDetails? launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        Future.delayed(const Duration(seconds: 1), () {
          onAlarmTriggered?.call(launchDetails.notificationResponse!.payload!);
        });
      }
    } catch (_) {}

    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      onAlarmTriggered?.call(response.payload!);
    }
  }

  /// Membuat detail notifikasi Android secara fleksibel sesuai fallback level.
  /// gunakanAlarmAttributes: true => stream volume alarm (bisa ditolak Android 14+ tanpa izin exact alarm).
  /// gunakanAlarmAttributes: false => stream volume notifikasi default (aman 100% dari SecurityException).
  static AndroidNotificationDetails _buatAndroidDetails({
    required bool gunakanFullScreenIntent,
    required bool gunakanFlags,
    required bool gunakanAlarmAttributes,
  }) {
    // ID channel unik per kombinasi fitur agar Android selalu membuat channel
    // baru sesuai konfigurasi saat ini (channel lama tidak bisa diubah).
    final channelId = [
      _baseChannelId,
      'fs${gunakanFullScreenIntent ? 1 : 0}',
      'fl${gunakanFlags ? 1 : 0}',
      'al${gunakanAlarmAttributes ? 1 : 0}',
    ].join('_');

    return AndroidNotificationDetails(
      channelId,
      'Alarm Pengingat Tugas',
      channelDescription: 'Notifikasi alarm untuk pengingat tugas',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: gunakanFullScreenIntent,
      playSound: true,
      ongoing: gunakanFlags,
      additionalFlags: gunakanFlags ? Int32List.fromList(<int>[4]) : null, // FLAG_INSISTENT (loop sound)
      enableVibration: true,
      category: gunakanFlags ? AndroidNotificationCategory.alarm : null,
      visibility: gunakanFlags ? NotificationVisibility.public : null,
      audioAttributesUsage: gunakanAlarmAttributes
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
    );
  }

  /// Cek apakah exact alarm diizinkan; fallback ke inexact jika tidak.
  static Future<AndroidScheduleMode> _modeJadwalAman() async {
    try {
      final plugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bisaExact = await plugin?.canScheduleExactNotifications() ?? false;
      return bisaExact
          ? AndroidScheduleMode.alarmClock // Menggunakan mode ALARM CLOCK bawaan HP
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  static Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? repeatComp,
    AndroidScheduleMode mode, {
    required bool gunakanFullScreenIntent,
    required bool gunakanFlags,
    required bool gunakanAlarmAttributes,
  }) {
    final androidDetails = _buatAndroidDetails(
      gunakanFullScreenIntent: gunakanFullScreenIntent,
      gunakanFlags: gunakanFlags,
      gunakanAlarmAttributes: gunakanAlarmAttributes,
    );

    return _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload,
      androidScheduleMode: mode,
      matchDateTimeComponents: repeatComp,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Rantai penjadwalan alarm multi-level (8 tingkatan fallback) untuk mengantisipasi
  /// segala bentuk SecurityException dan batasan permission di Android 13/14+ (Infinix XOS):
  static Future<void> _jalankanScheduleChain(
    int id,
    String title,
    String body,
    tz.TZDateTime date,
    String? payload,
    DateTimeComponents? repeatComp,
    AndroidScheduleMode mode,
  ) async {
    // Level 1: AlarmClock + FullScreen + Flags + AlarmAttributes (Alarm HP Asli)
    try {
      await _schedule(id, title, body, date, payload, repeatComp, AndroidScheduleMode.alarmClock,
          gunakanFullScreenIntent: true, gunakanFlags: true, gunakanAlarmAttributes: true);
      debugPrint('[AlarmService] Level 1 Sukses (AlarmClock + FullScreen + Flags + AlarmAttributes)');
      return;
    } catch (e1) {
      debugPrint('[AlarmService] Level 1 Gagal: $e1. Coba Level 2...');
      
      // Level 2: Exact (alarmClock) + Tanpa FullScreen + Flags + AlarmAttributes
      try {
        await _schedule(id, title, body, date, payload, repeatComp, AndroidScheduleMode.alarmClock,
            gunakanFullScreenIntent: false, gunakanFlags: true, gunakanAlarmAttributes: true);
        debugPrint('[AlarmService] Level 2 Sukses (AlarmClock + NoFullScreen + Flags + AlarmAttributes)');
        return;
      } catch (e2) {
        debugPrint('[AlarmService] Level 2 Gagal: $e2. Coba Level 3...');
        
        // Level 3: Exact (exactAllowWhileIdle) + FullScreen + Flags + AlarmAttributes
        try {
          await _schedule(id, title, body, date, payload, repeatComp, AndroidScheduleMode.exactAllowWhileIdle,
              gunakanFullScreenIntent: true, gunakanFlags: true, gunakanAlarmAttributes: true);
          debugPrint('[AlarmService] Level 3 Sukses (Exact + FullScreen + Flags + AlarmAttributes)');
          return;
        } catch (e3) {
          debugPrint('[AlarmService] Level 3 Gagal: $e3. Coba Level 4...');

          // Level 4: Exact (exactAllowWhileIdle) + Tanpa FullScreen + Flags + AlarmAttributes
          try {
            await _schedule(id, title, body, date, payload, repeatComp, AndroidScheduleMode.exactAllowWhileIdle,
                gunakanFullScreenIntent: false, gunakanFlags: true, gunakanAlarmAttributes: true);
            debugPrint('[AlarmService] Level 4 Sukses (Exact + NoFullScreen + Flags + AlarmAttributes)');
            return;
          } catch (e4) {
            debugPrint('[AlarmService] Level 4 Gagal: $e4. Coba Level 5...');

            // Level 5: Inexact + FullScreen + Flags + AlarmAttributes
            try {
              await _schedule(
                id, title, body, date, payload, repeatComp,
                AndroidScheduleMode.inexactAllowWhileIdle,
                gunakanFullScreenIntent: true, gunakanFlags: true, gunakanAlarmAttributes: true,
              );
              debugPrint('[AlarmService] Level 5 Sukses (Inexact + FullScreen + Flags + AlarmAttributes)');
              return;
            } catch (e5) {
              debugPrint('[AlarmService] Level 5 Gagal: $e5. Coba Level 6...');
              
              // Level 6: Inexact + Tanpa FullScreen + Flags + AlarmAttributes
              try {
                await _schedule(
                  id, title, body, date, payload, repeatComp,
                  AndroidScheduleMode.inexactAllowWhileIdle,
                  gunakanFullScreenIntent: false, gunakanFlags: true, gunakanAlarmAttributes: true,
                );
                debugPrint('[AlarmService] Level 6 Sukses (Inexact + NoFullScreen + Flags + AlarmAttributes)');
                return;
              } catch (e6) {
                debugPrint('[AlarmService] Level 6 Gagal: $e6. Coba Level 7...');
                
                // Level 7: Inexact + Tanpa FullScreen + Flags + NotificationAttributes (Menghindari USAGE_ALARM Android 14)
                try {
                  await _schedule(
                    id, title, body, date, payload, repeatComp,
                    AndroidScheduleMode.inexactAllowWhileIdle,
                    gunakanFullScreenIntent: false, gunakanFlags: true, gunakanAlarmAttributes: false,
                  );
                  debugPrint('[AlarmService] Level 7 Sukses (Inexact + NoFullScreen + Flags + NotificationAttributes)');
                  return;
                } catch (e7) {
                  debugPrint('[AlarmService] Level 7 Gagal: $e7. Coba Level 8 (Notifikasi Dasar)...');
                  
                  // Level 8: Inexact + Tanpa FullScreen + Tanpa Flags + NotificationAttributes (Pasti Sukses)
                  try {
                    await _schedule(
                      id, title, body, date, payload, repeatComp,
                      AndroidScheduleMode.inexactAllowWhileIdle,
                      gunakanFullScreenIntent: false, gunakanFlags: false, gunakanAlarmAttributes: false,
                    );
                    debugPrint('[AlarmService] Level 8 Sukses (Notifikasi Dasar)');
                    return;
                  } catch (e8) {
                    debugPrint('[AlarmService] Semua level gagal: $e8');
                    throw Exception('Semua fallback notifikasi gagal: $e8');
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  static Future<void> jadwalkanAlarm(TaskModel task) async {
    if (task.waktuAlarm == null) return;

    await batalkanAlarm(task.notificationId);

    // PENTING: jadwalkan dalam timezone LOKAL perangkat (bukan UTC mentah).
    // Sebelumnya memakai tz.UTC sehingga waktu alarm bergeser sesuai offset
    // (WIB = +7 jam) dan tidak berbunyi pada jam yang di-setting user.
    var scheduledDate = tz.TZDateTime.from(task.waktuAlarm!, tz.local);
    final tzNow = tz.TZDateTime.now(tz.local);

    // Jika waktu sudah lewat, sesuaikan ke masa depan
    if (scheduledDate.isBefore(tzNow)) {
      if (task.pengulangan == Pengulangan.harian) {
        while (scheduledDate.isBefore(tzNow)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
      } else if (task.pengulangan == Pengulangan.mingguan) {
        while (scheduledDate.isBefore(tzNow)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }
      } else if (task.pengulangan == Pengulangan.bulanan) {
        while (scheduledDate.isBefore(tzNow)) {
          var nextMonth = scheduledDate.month + 1;
          var nextYear = scheduledDate.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          int targetDay = scheduledDate.day;
          int maxDays = DateTime(nextYear, nextMonth + 1, 0).day;
          if (targetDay > maxDays) {
            targetDay = maxDays;
          }
          scheduledDate = tz.TZDateTime(
            tz.local,
            nextYear,
            nextMonth,
            targetDay,
            scheduledDate.hour,
            scheduledDate.minute,
            scheduledDate.second,
            scheduledDate.millisecond,
            scheduledDate.microsecond,
          );
        }
      } else {
        // Sekali, dan waktu sudah lewat → lewati dengan aman, matikan status alarm
        task.alarmAktif = false;
        if (task.isInBox) {
          try {
            await task.save();
          } catch (_) {}
        }
        debugPrint('[AlarmService] Alarm waktu lewat dilewati secara aman.');
        return;
      }
    }

    final body = task.deskripsi.isNotEmpty
        ? task.deskripsi
        : 'Waktunya menyelesaikan tugas!';

    DateTimeComponents? repeatComp;
    if (task.pengulangan == Pengulangan.harian) {
      repeatComp = DateTimeComponents.time;
    } else if (task.pengulangan == Pengulangan.mingguan) {
      repeatComp = DateTimeComponents.dayOfWeekAndTime;
    } else if (task.pengulangan == Pengulangan.bulanan) {
      repeatComp = DateTimeComponents.dayOfMonthAndTime;
    }

    final mode = await _modeJadwalAman();
    try {
      await _jalankanScheduleChain(
        task.notificationId,
        '⏰ ${task.judul}',
        body,
        scheduledDate,
        task.id,
        repeatComp,
        mode,
      );
    } catch (eFinal) {
      debugPrint('[AlarmService] Semua fallback (lokal & UTC) gagal: $eFinal');
      throw Exception(eFinal.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Membungkus metode pembatalan dengan try-catch agar tidak pernah memicu crash/PlatformException
  static Future<void> batalkanAlarm(int notificationId) async {
    try {
      await _notificationsPlugin.cancel(notificationId);
      debugPrint('[AlarmService] Berhasil membatalkan alarm id=$notificationId');
    } catch (e) {
      debugPrint('[AlarmService] Gagal membatalkan alarm id=$notificationId secara native: $e');
    }
  }

  static Future<void> snoozeAlarm(TaskModel task, int menitTunda) async {
    final waktuSnooze = DateTime.now().add(Duration(minutes: menitTunda));
    final tzWaktu = tz.TZDateTime.from(waktuSnooze, tz.local);

    final mode = await _modeJadwalAman();
    try {
      await _jalankanScheduleChain(
        task.notificationId + 10000,
        '⏰ Snooze: ${task.judul}',
        'Pengingat ditunda $menitTunda menit',
        tzWaktu,
        task.id,
        null,
        mode,
      );
    } catch (_) {}
  }

  static Future<void> batalkanSemuaAlarm() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
    await hentikanSuaraAlarm();
  }

  /// Cek apakah exact alarm diizinkan (untuk ditampilkan di UI pengaturan).
  static Future<bool> cekIzinExactAlarm() async {
    try {
      final plugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await plugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Buka halaman pengaturan exact alarm di sistem.
  static Future<void> bukaSettingExactAlarm() async {
    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// Memutar suara alarm dengan urutan prioritas:
  /// 1. File custom pilihan user (jika file masih ada di storage)
  /// 2. Nada alarm default HP (looping via stream volume alarm)
  /// 3. Notifikasi bersuara sebagai fallback terakhir
  static Future<void> putarSuaraAlarm({String? filePath}) async {
    // Hentikan AudioPlayer (file custom) yang sedang jalan
    await _hentikanAudioPlayer();

    if (filePath != null && filePath.isNotEmpty) {
      try {
        if (File(filePath).existsSync()) {
          _audioPlayer = AudioPlayer();
          await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer!.play(DeviceFileSource(filePath));
          // Pastikan ringtone player tidak ikut berbunyi
          try { await _ringtonePlayer.stop(); } catch (_) {}
          return;
        }
      } catch (_) {
        await _hentikanAudioPlayer();
      }
    }

    // Stop ringtone lama sebelum play yang baru
    try { await _ringtonePlayer.stop(); } catch (_) {}
    try {
      await _ringtonePlayer.playAlarm(volume: 1.0);
      return;
    } catch (_) {
      try {
        await _notificationsPlugin.show(
          99999,
          '⏰ Alarm Berbunyi',
          'Ketuk untuk merespon alarm',
          NotificationDetails(
            android: _buatAndroidDetails(
              gunakanFullScreenIntent: false,
              gunakanFlags: false,
              gunakanAlarmAttributes: false,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: 'default',
            ),
          ),
        );
      } catch (_) {}
    }
  }

  static Future<void> _hentikanAudioPlayer() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
      } catch (_) {}
      _audioPlayer = null;
    }
  }

  static Future<void> hentikanSuaraAlarm() async {
    await _hentikanAudioPlayer();
    try {
      await _ringtonePlayer.stop();
    } catch (_) {}
    try {
      await _notificationsPlugin.cancel(99999);
    } catch (_) {}
  }
}
