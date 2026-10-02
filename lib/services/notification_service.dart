import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_item.dart';
import '../models/subject.dart';
import '../utils/deadline_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static const String channelId = 'catatan_tugas_kuliah_channel';
  static const String channelName = 'Pengingat Tugas Kuliah';
  static const String channelDescription =
      'Notifikasi pengingat tenggat waktu tugas dan jadwal kuliah';

  /// Inisialisasi plugin notifikasi dan database timezone
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Inisialisasi database zona waktu offline
      tz.initializeTimeZones();

      if (!_isSupportedPlatform) {
        _isInitialized = true;
        return;
      }

      const androidSettings = AndroidInitializationSettings('ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // Buat Android Notification Channel dengan prioritas tinggi
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidPlugin != null) {
          const androidChannel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );

          await androidPlugin.createNotificationChannel(androidChannel);
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService successfully initialized.');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  /// Minta izin notifikasi (terutama Android 13+ & iOS)
  Future<bool> requestPermission() async {
    if (!_isInitialized) await init();
    if (!_isSupportedPlatform) return true;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
    return true;
  }

  /// Menampilkan notifikasi langsung (instant) dengan logo aplikasi
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();
    if (!_isSupportedPlatform) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Jadwalkan pengingat deadline untuk tugas kuliah dengan logo aplikasi
  Future<void> scheduleTaskDeadlineReminder({
    required Subject subject,
    required TaskItem task,
  }) async {
    if (!_isInitialized) await init();
    if (!_isSupportedPlatform) return;

    if (task.deadline == null || task.deadline!.trim().isEmpty || task.isDone) {
      // Batalkan jika tugas selesai atau deadline kosong
      await cancelTaskReminder(task.id);
      return;
    }

    await cancelTaskReminder(task.id);
    final date = DeadlineHelper.parseDate(task.deadline!);
    if (date == null) return;

    // Jadwalkan pengingat pada jam 08:00 pagi di hari deadline
    var scheduledDate = DateTime(date.year, date.month, date.day, 8, 0, 0);

    // Jika jam 08:00 hari ini sudah lewat tapi deadline hari ini, jadwalkan 1 menit dari sekarang
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        scheduledDate = now.add(const Duration(minutes: 1));
      } else {
        // Deadline sudah terlewat di masa lalu, tidak perlu jadwal
        return;
      }
    }

    final id = _generateNotificationId(task.id);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: '⏰ Deadline Tugas Hari Ini: ${subject.name}',
        body:
            'Tugas "${task.title}" harus diselesaikan hari ini (${task.deadline})!',
        scheduledDate: tzDateTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint(
        'Scheduled notification for task "${task.title}" at $scheduledDate (id: $id)',
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Batalkan notifikasi spesifik tugas
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_isSupportedPlatform) return;
    final id = _generateNotificationId(taskId);
    await _notificationsPlugin.cancel(id: id);
  }

  /// Batalkan seluruh notifikasi terjadwal
  Future<void> cancelAll() async {
    if (!_isSupportedPlatform) return;
    await _notificationsPlugin.cancelAll();
  }

  Future<void> cancelAllPending() async {
    if (!_isInitialized) await init();
    if (!_isSupportedPlatform) return;
    await _notificationsPlugin.cancelAllPendingNotifications();
  }

  /// Generator ID integer unik berbasis hashcode taskId
  int _generateNotificationId(String key) {
    var hash = 2166136261;
    for (final code in key.codeUnits) {
      hash = ((hash ^ code) * 16777619) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
