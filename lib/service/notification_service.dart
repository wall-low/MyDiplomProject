import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  bool _initialized = false;
  String? _currentUserId;

  // Callback для навигации при нажатии на уведомление
  static void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Запрашиваем разрешение на Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[Notifications] Initialized');
  }

  /// Запустить polling для текущего пользователя
  void startPolling(String userId) {
    _currentUserId = userId;
    stopPolling();

    // Polling каждые 10 секунд
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkForUpdates(),
    );

    debugPrint('[Notifications] Polling started for user: $userId');
  }

  /// Остановить polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('[Notifications] Polling stopped');
  }

  /// Проверить наличие новых сообщений и бронирований
  Future<void> _checkForUpdates() async {
    if (_currentUserId == null) return;

    final pb = PocketBaseService().client;
    if (!PocketBaseService().isAuthenticated) return;

    try {
      await Future.wait([
        _checkNewMessages(pb),
        _checkNewBookings(pb),
      ]);
    } catch (e) {
      debugPrint('[Notifications] Polling error: $e');
    }
  }

  /// Проверить новые непрочитанные сообщения
  Future<void> _checkNewMessages(PocketBase pb) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckKey = 'last_message_check_$_currentUserId';
    final lastCheck = prefs.getString(lastCheckKey) ?? '';

    String filter =
        '(receiverId="$_currentUserId" && isRead=false)';
    if (lastCheck.isNotEmpty) {
      filter += ' && created>"$lastCheck"';
    }

    try {
      final result = await pb.collection('messages').getList(
            filter: filter,
            perPage: 10,
            sort: '-created',
          );

      if (result.items.isNotEmpty) {
        // Сохраняем время последней проверки
        await prefs.setString(
            lastCheckKey, result.items.first.created);

        // Группируем по отправителю
        final senderIds = <String>{};
        for (final msg in result.items) {
          senderIds.add(msg.data['senderId'] as String);
        }

        for (final senderId in senderIds) {
          final senderMessages = result.items
              .where((m) => m.data['senderId'] == senderId)
              .toList();

          // Получаем имя отправителя
          String senderName = 'Новое сообщение';
          try {
            final sender =
                await pb.collection('users').getOne(senderId);
            senderName = sender.data['name'] as String? ?? 'Пользователь';
          } catch (_) {}

          final count = senderMessages.length;
          final lastMsg = senderMessages.first;
          final msgType = lastMsg.data['type'] as String? ?? 'text';

          String body;
          if (count > 1) {
            body = '$count новых сообщений';
          } else if (msgType == 'image') {
            body = 'Отправил(а) фото';
          } else if (msgType == 'audio') {
            body = 'Отправил(а) голосовое сообщение';
          } else {
            body = lastMsg.data['message'] as String? ?? '';
            if (body.length > 100) body = '${body.substring(0, 100)}...';
          }

          await _showNotification(
            id: senderId.hashCode,
            title: senderName,
            body: body,
            payload: 'chat:$senderId',
          );
        }
      }
    } catch (e) {
      debugPrint('[Notifications] Check messages error: $e');
    }
  }

  /// Проверить новые бронирования
  Future<void> _checkNewBookings(PocketBase pb) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckKey = 'last_booking_check_$_currentUserId';
    final lastCheck = prefs.getString(lastCheckKey) ?? '';

    // Проверяем слоты где текущий пользователь — репетитор и статус pending
    String filter =
        '(tutorId="$_currentUserId" && bookingStatus="pending")';
    if (lastCheck.isNotEmpty) {
      filter += ' && updated>"$lastCheck"';
    }

    try {
      final result = await pb.collection('slots').getList(
            filter: filter,
            perPage: 10,
            sort: '-updated',
          );

      if (result.items.isNotEmpty) {
        await prefs.setString(
            lastCheckKey, result.items.first.get<String>('updated'));

        final count = result.items.length;

        await _showNotification(
          id: 'bookings'.hashCode,
          title: 'Запрос на бронирование',
          body: count == 1
              ? 'Новый запрос на занятие'
              : '$count новых запросов на занятия',
          payload: 'booking',
        );
      }
    } catch (e) {
      debugPrint('[Notifications] Check bookings error: $e');
    }
  }

  /// Показать уведомление
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ucheba_ryadom_channel',
      'Учеба рядом',
      channelDescription: 'Уведомления приложения Учеба рядом',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Сбросить счётчик проверок (при логауте)
  Future<void> reset() async {
    stopPolling();
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('last_message_check_') ||
          key.startsWith('last_booking_check_')) {
        await prefs.remove(key);
      }
    }
  }
}
