import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/subject.dart';
import '../models/tuition_payment.dart';
import 'reminder_plan.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  final opened = ValueNotifier<String?>(null);

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
          opened.value = response.payload;
        },
      );
      final launch = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        opened.value = launch?.notificationResponse?.payload;
      }

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

  Future<void> syncSubjects(
    List<Subject> subjects, {
    List<TuitionPayment> payments = const [],
  }) async {
    if (!_isInitialized) await init();
    if (!_isSupportedPlatform) return;
    final plan = planReminders(subjects, DateTime.now(), payments: payments);
    final used = <int>{};
    final scheduled = <int, PlannedReminder>{};
    // Android vendors may cap AlarmManager at 500 alarms; reserve room for system notifications.
    for (final reminder in plan.take(450)) {
      var id = _generateNotificationId(reminder.key);
      while (!used.add(id)) {
        id = (id + 1) & 0x7FFFFFFF;
      }
      scheduled[id] = reminder;
    }
    for (final pending
        in await _notificationsPlugin.pendingNotificationRequests()) {
      if (!scheduled.containsKey(pending.id)) {
        await _notificationsPlugin.cancel(id: pending.id);
      }
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final entry in scheduled.entries) {
      final reminder = entry.value;
      await _notificationsPlugin.zonedSchedule(
        id: entry.key,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
        notificationDetails: details,
        payload: reminder.payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    if (plan.length > 450) {
      throw StateError(
        'Batas pengingat HP tercapai. Kurangi jumlah pengingat atau panjang periode Mentari.',
      );
    }
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
