import 'dart:async';
import 'dart:io'; // ✅ Для File.readAsBytes()
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ✅ Для MultipartFile
import 'package:p7/models/messenge.dart';
import 'package:p7/models/chat.dart';
import 'package:p7/service/auth.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';

/// Сервис для работы с чатами и сообщениями в PocketBase
///
/// Мигрировано с Cloud Firestore на PocketBase
/// Причина: риск блокировки Firebase в РФ перед защитой диплома
///
/// ВАЖНЫЕ ИЗМЕНЕНИЯ В СТРУКТУРЕ ДАННЫХ:
///
/// 1. FIRESTORE (вложенная структура):
///    chat_room/{chatRoomId} (документ с метаданными)
///      └─ messages/{msgId} (подколлекция сообщений)
///
/// 2. POCKETBASE (плоская структура):
///    messages (коллекция со ВСЕМИ сообщениями)
///      - chatRoomId: "user1_user2" (поле для фильтрации)
///
/// ПОЧЕМУ:
/// PocketBase не поддерживает подколлекции (subcollections)
/// Все сообщения хранятся в одной коллекции, фильтруем по chatRoomId
///
/// УЛУЧШЕНИЯ (последняя версия):
/// ✅ Realtime subscriptions через pb.collection().subscribe()
/// ✅ Кеширование результатов для производительности
/// ✅ Two-table pattern (messages + chats) для быстрого списка чатов
class ChatService extends ChangeNotifier {
  // ИЗМЕНЕНИЕ 1: Заменили Firebase на PocketBase
  //
  // БЫЛО:
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  //
  // СТАЛО:
  final _pb = PocketBaseService().client;

  // ============================================================================
  // КЕШИРОВАНИЕ ДЛЯ ПРОИЗВОДИТЕЛЬНОСТИ
  // ============================================================================

  /// Кеш для списка всех пользователей
  List<Map<String, dynamic>>? _cachedUserList;
  DateTime? _userListCacheTime;
  static const _cacheValidDuration = Duration(minutes: 5);

  /// Кеш для заблокированных пользователей (по userId)
  final Map<String, List<Map<String, dynamic>>> _cachedBlockedUsers = {};
  final Map<String, DateTime> _blockedUsersCacheTime = {};

  /// Кеш для списка чатов
  List<Chat>? _cachedChats;
  DateTime? _chatsCacheTime;

  /// Stream controllers для realtime подписок
  final Map<String, StreamController<List<Message>>> _messageStreamControllers =
      {};
  final Map<String, UnsubscribeFunc> _subscriptions = {};

  /// НОВОЕ: Stream controller для списка чатов
  StreamController<List<Chat>>? _chatsStreamController;
  UnsubscribeFunc? _chatsSubscription;

  // ============================================================================
  // УПРАВЛЕНИЕ КЕШЕМ
  // ============================================================================

  /// Проверка валидности кеша
  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheValidDuration;
  }

  /// Очистить весь кеш
  void clearCache() {
    _cachedUserList = null;
    _userListCacheTime = null;
    _cachedBlockedUsers.clear();
    _blockedUsersCacheTime.clear();
    _cachedChats = null;
    _chatsCacheTime = null;
    print('[ChatService] Кеш очищен');
    notifyListeners();
  }

  /// Очистить кеш чатов (вызывается после отправки сообщения)
  void _invalidateChatsCache() {
    _cachedChats = null;
    _chatsCacheTime = null;
  }

  /// Очистить кеш пользователей
  void invalidateUserCache() {
    _cachedUserList = null;
    _userListCacheTime = null;
  }

  /// Очистить кеш заблокированных для конкретного пользователя
  void _invalidateBlockedCache(String userId) {
    _cachedBlockedUsers.remove(userId);
    _blockedUsersCacheTime.remove(userId);
  }

  /// Dispose - очистка ресурсов
  @override
  void dispose() {
    // Отписываемся от всех realtime подписок
    for (var unsubscribe in _subscriptions.values) {
      unsubscribe();
    }
    _subscriptions.clear();

    // Закрываем все stream controllers для сообщений
    for (var controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

    // НОВОЕ: Отписываемся от чатов и закрываем контроллер
    _chatsSubscription?.call();
    _chatsStreamController?.close();

    super.dispose();
  }

  /// Получить список всех пользователей (кроме текущего)
  ///
  /// БЫЛО (Firestore):
  /// Stream<List<Map<String, dynamic>>> - реактивный поток
  ///
  /// СТАЛО (PocketBase):
  /// Future<List<Map<String, dynamic>>> - одноразовый запрос с КЕШИРОВАНИЕМ
  ///
  /// ✅ УЛУЧШЕНИЕ: Кеш на 5 минут для снижения нагрузки на сервер
  Future<List<Map<String, dynamic>>> getUserList({bool forceRefresh = false}) async {
    try {
      // Проверяем кеш (если не требуется принудительное обновление)
      if (!forceRefresh && _isCacheValid(_userListCacheTime)) {
        print('[ChatService] Используется кеш для getUserList()');
        return _cachedUserList!;
      }

      final currentUserId = Auth().getCurrentUid();

      // ИЗМЕНЕНИЕ 2: getFullList() вместо snapshots()
      //
      // БЫЛО:
      // _firestore.collection('Users').snapshots()
      //
      // СТАЛО:
      // _pb.collection('users').getFullList()
      //
      // getFullList() получает все записи, но БЕЗ реактивности
      final records = await _pb.collection('users').getFullList();

      // Фильтруем текущего пользователя и преобразуем в Map
      final userList = records
          .where((record) => record.id != currentUserId)
          .map((record) => {
                'uid': record.id,
                'name': record.data['name'] ?? '',
                'email': record.data['email'] ?? '',
                'username': record.data['username'] ?? '',
                'avatarUrl': record.data['avatar'] ?? '',
                'city': record.data['city'] ?? '',
                'role': record.data['role'] ?? '',
              })
          .toList();

      // Сохраняем в кеш
      _cachedUserList = userList;
      _userListCacheTime = DateTime.now();
      print('[ChatService] Кеш обновлён для getUserList() (${userList.length} пользователей)');

      return userList;
    } catch (e) {
      print('[ChatService] Ошибка получения пользователей: $e');
      return [];
    }
  }

  /// Получить пользователей исключая заблокированных
  ///
  /// БЫЛО (Firestore):
  /// Stream с вложенным запросом к подколлекции BlockedUser
  ///
  /// СТАЛО (PocketBase):
  /// Future с запросом к отдельной коллекции blocked_users
  Future<List<Map<String, dynamic>>> getUsersExcludingBlocked() async {
    try {
      final currentUserId = Auth().getCurrentUid();

      // ИЗМЕНЕНИЕ 3: Получаем заблокированных из отдельной коллекции
      //
      // БЫЛО (Firestore - подколлекция):
      // _firestore.collection('Users').doc(currentUserId).collection('BlockedUser')
      //
      // СТАЛО (PocketBase - отдельная коллекция):
      // _pb.collection('blocked_users').getList(filter: 'userId="$currentUserId"')
      //
      // ПОЧЕМУ:
      // PocketBase не поддерживает подколлекции
      // Используем отдельную коллекцию blocked_users с полями:
      // - userId (relation → users) - кто заблокировал
      // - blockedUserId (relation → users) - кого заблокировали
      final blockedRecords = await _pb.collection('blocked_users').getList(
            filter: 'userId="$currentUserId"',
          );

      final blockedUserIds =
          blockedRecords.items.map((r) => r.data['blockedUserId'] as String).toList();

      // Получаем всех пользователей
      final allUsers = await _pb.collection('users').getFullList();

      // Фильтруем текущего пользователя и заблокированных
      return allUsers
          .where((record) =>
              record.id != currentUserId && !blockedUserIds.contains(record.id))
          .map((record) => {
                'uid': record.id,
                'name': record.data['name'] ?? '',
                'email': record.data['email'] ?? '',
                'username': record.data['username'] ?? '',
                'avatarUrl': record.data['avatar'] ?? '',
              })
          .toList();
    } catch (e) {
      print('[ChatService] Ошибка получения пользователей (без блокировок): $e');
      return [];
    }
  }

  /// Получить список активных чатов пользователя
  ///
  /// УПРОЩЕННАЯ ВЕРСИЯ для начала
  /// Возвращает список чатов с последним сообщением
  ///
  /// TODO: Добавить подсчет непрочитанных сообщений
  /// TODO: Добавить реактивность через subscribe()
  Future<List<Map<String, dynamic>>> getActiveChats() async {
    try {
      final currentUserId = Auth().getCurrentUid();

      // ИЗМЕНЕНИЕ 4: Запрос сообщений с фильтром по участникам
      //
      // В PocketBase нет отдельной коллекции chat_room
      // Все чаты определяются через сообщения с chatRoomId
      //
      // Логика:
      // 1. Получаем все сообщения где текущий пользователь - отправитель или получатель
      // 2. Группируем по chatRoomId
      // 3. Для каждого чата берем последнее сообщение
      final messages = await _pb.collection('messages').getList(
            filter: 'senderId="$currentUserId" || receiverId="$currentUserId"',
            sort: '-created', // Сортировка по дате (новые первыми)
            perPage: 500, // Ограничение для производительности
          );

      // Группируем сообщения по chatRoomId
      final Map<String, RecordModel> lastMessageByChat = {};
      for (var msg in messages.items) {
        final chatRoomId = msg.data['chatRoomId'] as String;
        // Сохраняем только если это первое сообщение для этого чата
        // (они уже отсортированы по дате, поэтому первое = последнее)
        if (!lastMessageByChat.containsKey(chatRoomId)) {
          lastMessageByChat[chatRoomId] = msg;
        }
      }

      // Получаем заблокированных пользователей
      final blockedRecords = await _pb.collection('blocked_users').getList(
            filter: 'userId="$currentUserId"',
          );
      final blockedUserIds =
          blockedRecords.items.map((r) => r.data['blockedUserId'] as String).toList();

      // Формируем список чатов
      final chatsList = <Map<String, dynamic>>[];

      for (var entry in lastMessageByChat.entries) {
        final chatRoomId = entry.key;
        final lastMsg = entry.value;

        // Определяем ID собеседника из chatRoomId
        // chatRoomId формат: "userId1_userId2" (отсортированы)
        final participants = chatRoomId.split('_');
        final otherUserId =
            participants[0] == currentUserId ? participants[1] : participants[0];

        // Пропускаем заблокированных
        if (blockedUserIds.contains(otherUserId)) continue;

        // Получаем данные собеседника
        try {
          final userRecord = await _pb.collection('users').getOne(otherUserId);

          // Считаем непрочитанные сообщения для этого чата
          final unreadCount = await getUnreadCount(currentUserId, otherUserId);

          chatsList.add({
            'chatRoomId': chatRoomId,
            'otherUserId': otherUserId,
            'username': userRecord.data['username'] ?? '',
            'avatarUrl': userRecord.data['avatar'] ?? '',
            'lastMessage': lastMsg.data['message'] ?? '',
            'lastMessageType': lastMsg.data['type'] ?? 'text',
            'lastTimestamp': lastMsg.created,
            'lastSenderId': lastMsg.data['senderId'] ?? '',
            'unreadCount': unreadCount,
          });
        } catch (e) {
          print('[ChatService] Ошибка получения данных пользователя $otherUserId: $e');
          continue;
        }
      }

      // Сортируем по времени последнего сообщения
      chatsList.sort((a, b) {
        final aTime = DateTime.parse(a['lastTimestamp']);
        final bTime = DateTime.parse(b['lastTimestamp']);
        return bTime.compareTo(aTime); // От новых к старым
      });

      return chatsList;
    } catch (e) {
      print('[ChatService] Ошибка получения активных чатов: $e');
      return [];
    }
  }

  /// Отправка текстового сообщения
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ❌ УДАЛЕНО: chatRoomId (строка "user1_user2")
  /// ✅ ДОБАВЛЕНО: chatId (RelationField → chats.id)
  ///
  /// НОВЫЙ АЛГОРИТМ:
  /// 1. Получаем chatId через _getChatIdByUsers() (находит или создаёт чат)
  /// 2. Создаём сообщение с chatId (RelationField)
  /// 3. Обновляем метаданные через _updateChatMetadata()
  ///
  /// Коллекция messages содержит:
  /// - chatId: relation → chats.id  ← НОВОЕ!
  /// - senderId, receiverId: участники
  /// - message: текст сообщения
  /// - type: тип (text/image/audio)
  /// - isRead: прочитано ли
  Future<void> sendMessage(String receiverID, String message,
      {String type = 'text'}) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      print('[ChatService] 📤 Отправка сообщения от: $currentUserId → $receiverID');

      // ✅ ШАГ 1: Получаем или создаём чат
      final chatId = await _getChatIdByUsers(currentUserId, receiverID);

      // Создаем объект сообщения с текущим временем
      final messageTimestamp = DateTime.now();
      final newMessage = Message(
        senderID: currentUserId,
        senderEmail: currentUserEmail,
        receiverID: receiverID,
        message: message,
        timestamp: messageTimestamp,
        type: type,
      );

      // ✅ ШАГ 2: Создаём сообщение с chatId (RelationField!)
      final messageData = {
        ...newMessage.toMap(),
        'chatId': chatId, // ✅ ИЗМЕНЕНО: используем chatId вместо chatRoomId
        'isRead': false,
      };

      final createdMessage = await _pb.collection('messages').create(body: messageData);

      print('[ChatService] ✅ Сообщение отправлено: ${createdMessage.id}');

      // ✅ ШАГ 3: Обновляем метаданные чата
      await _updateChatMetadata(
        chatId: chatId, // ✅ ИЗМЕНЕНО: передаём chatId
        lastMessage: message,
        lastMessageType: type,
        lastSenderId: currentUserId,
        messageTimestamp: messageTimestamp,
      );

      // ✅ УЛУЧШЕНИЕ: Инвалидируем кеш чатов
      _invalidateChatsCache();
    } catch (e) {
      print('[ChatService] Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  /// Отправка изображения через PocketBase Storage
  ///
  /// ПАРАМЕТРЫ:
  /// - receiverId: ID получателя
  /// - filePath: Локальный путь к файлу изображения
  ///
  /// АЛГОРИТМ:
  /// 1. Получаем chatId
  /// 2. Загружаем файл через FormData в поле 'file'
  /// 3. Обновляем метаданные чата
  Future<void> sendMessageWithImage({
    required String receiverId,
    required String filePath, // ✅ ИЗМЕНЕНО: filePath вместо imageUrl
  }) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      print('[ChatService] 📤 Отправка изображения от: $currentUserId → $receiverId');
      print('[ChatService] 📁 Путь к файлу: $filePath');

      // ✅ ШАГ 1: Получаем или создаём чат
      final chatId = await _getChatIdByUsers(currentUserId, receiverId);

      final messageTimestamp = DateTime.now();

      // ✅ ШАГ 2: Подготавливаем данные с файлом
      final body = <String, dynamic>{
        'chatId': chatId,
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'message': '', // Пустое для файлов
        'type': 'image',
        'isRead': false,
        'timestamp': messageTimestamp.toIso8601String(),
      };

      // ✅ ИСПРАВЛЕНИЕ: Используем fromBytes() для явного контроля MIME-типа
      // Определяем MIME-тип по расширению файла
      String imageMimeType = 'image/jpeg'; // Default
      if (filePath.endsWith('.png')) {
        imageMimeType = 'image/png';
      } else if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
        imageMimeType = 'image/jpeg';
      } else if (filePath.endsWith('.gif')) {
        imageMimeType = 'image/gif';
      } else if (filePath.endsWith('.webp')) {
        imageMimeType = 'image/webp';
      }

      print('[ChatService] 🖼️ Detected image MIME type: $imageMimeType');

      final fileBytes = await File(filePath).readAsBytes();
      final fileName = filePath.split('/').last;

      final file = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: http.MediaType.parse(imageMimeType),
      );

      final createdMessage = await _pb.collection('messages').create(
        body: body,
        files: [file],
      );

      print('[ChatService] ✅ Изображение отправлено: ${createdMessage.id}');

      // ✅ ШАГ 3: Обновляем метаданные
      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: '📷 Фото',
        lastMessageType: 'image',
        lastSenderId: currentUserId,
        messageTimestamp: messageTimestamp,
      );

      _invalidateChatsCache();
    } catch (e) {
      print('[ChatService] ❌ Ошибка отправки изображения: $e');
      rethrow;
    }
  }

  /// Отправка аудио через PocketBase Storage
  ///
  /// ПАРАМЕТРЫ:
  /// - receiverId: ID получателя
  /// - filePath: Локальный путь к аудио файлу
  ///
  /// АЛГОРИТМ:
  /// 1. Получаем chatId
  /// 2. Загружаем файл через FormData в поле 'file'
  /// 3. Обновляем метаданные чата
  Future<void> sendMessageWithAudio({
    required String receiverId,
    required String filePath, // ✅ ИЗМЕНЕНО: filePath вместо audioUrl
  }) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      print('[ChatService] 📤 Отправка аудио от: $currentUserId → $receiverId');
      print('[ChatService] 📁 Путь к файлу: $filePath');

      // ✅ ШАГ 1: Получаем или создаём чат
      final chatId = await _getChatIdByUsers(currentUserId, receiverId);

      final messageTimestamp = DateTime.now();

      // ✅ ШАГ 2: Подготавливаем данные с файлом
      final body = <String, dynamic>{
        'chatId': chatId,
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'message': '', // Пустое для файлов
        'type': 'audio',
        'isRead': false,
        'timestamp': messageTimestamp.toIso8601String(),
      };

      // ✅ Загружаем файл через http.MultipartFile
      // ВАЖНО: Определяем MIME-тип СТРОГО по настройкам PocketBase!
      // Настройки в Admin UI: .m4a → audio/x-m4a (НЕ audio/mp4!)
      String mimeType = 'audio/x-m4a'; // Default для аудио
      if (filePath.endsWith('.m4a')) {
        mimeType = 'audio/x-m4a'; // ✅ ИСПРАВЛЕНО: соответствует PocketBase настройкам
      } else if (filePath.endsWith('.aac')) {
        mimeType = 'audio/aac';
      } else if (filePath.endsWith('.wav')) {
        mimeType = 'audio/wav';
      } else if (filePath.endsWith('.mp3')) {
        mimeType = 'audio/mpeg';
      } else if (filePath.endsWith('.oga') || filePath.endsWith('.ogg')) {
        mimeType = 'audio/ogg';
      } else if (filePath.endsWith('.mp4')) {
        mimeType = 'audio/mp4'; // Для чистых .mp4 аудио файлов
      }

      // ✅ ИСПРАВЛЕНИЕ: Используем fromBytes() для ЯВНОГО контроля MIME-типа
      // ПРОБЛЕМА: На Android, fromPath() использует native детекцию, которая
      // неправильно определяет .m4a как audio/mpeg вместо audio/x-m4a
      // РЕШЕНИЕ: Читаем файл в bytes и создаём MultipartFile вручную
      final fileBytes = await File(filePath).readAsBytes();
      final fileName = filePath.split('/').last;

      final file = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: http.MediaType.parse(mimeType), // ✅ Явно указываем правильный MIME
      );

      print('[ChatService] 🎵 Отправка аудио: $fileName (${mimeType})');

      final createdMessage = await _pb.collection('messages').create(
        body: body,
        files: [file],
      );

      print('[ChatService] ✅ Аудио отправлено: ${createdMessage.id}');
      print('[ChatService] 📋 Детали сообщения:');
      print('  - file: ${createdMessage.data['file']}');
      print('  - type: ${createdMessage.data['type']}');
      print('  - message: "${createdMessage.data['message']}"');

      // Пытаемся построить URL и проверить его
      if (createdMessage.data['file'] != null) {
        try {
          final testUrl = _pb.getFileUrl(createdMessage, createdMessage.data['file']).toString();
          print('[ChatService] 🔗 Построенный URL: $testUrl');
        } catch (e) {
          print('[ChatService] ❌ Ошибка построения URL: $e');
        }
      } else {
        print('[ChatService] ⚠️ Поле file пустое! Файл не загружен в PocketBase.');
      }

      // ✅ ШАГ 3: Обновляем метаданные
      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: '🎵 Аудио',
        lastMessageType: 'audio',
        lastSenderId: currentUserId,
        messageTimestamp: messageTimestamp,
      );

      _invalidateChatsCache();
    } catch (e) {
      print('[ChatService] ❌ Ошибка отправки аудио: $e');
      rethrow;
    }
  }

  // ============================================================================
  // REALTIME SUBSCRIPTIONS ДЛЯ СООБЩЕНИЙ
  // ============================================================================

  /// ✨ Получить сообщения чата в реальном времени (realtime)
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ❌ УДАЛЕНО: chatRoomId (строка)
  /// ✅ ДОБАВЛЕНО: получаем chatId через _getChatIdByUsers()
  /// ✅ ФИЛЬТР: 'chatId="..."' вместо 'chatRoomId="..."'
  ///
  /// ИСПОЛЬЗОВАНИЕ:
  /// ```dart
  /// final stream = chatService.getMessagesStream(userId, otherUserId);
  /// StreamBuilder(stream: stream, builder: (context, snapshot) { ... });
  /// ```
  ///
  /// ВАЖНО: Вызвать unsubscribeFromMessages() при dispose виджета!
  Stream<List<Message>> getMessagesStream(String userId, String otherUserId) {
    // Создаём broadcast controller для возврата
    final broadcastController = StreamController<List<Message>>.broadcast();

    // Запускаем async инициализацию
    _initializeMessageStream(userId, otherUserId, broadcastController);

    return broadcastController.stream;
  }

  /// Внутренний метод для async инициализации stream
  Future<void> _initializeMessageStream(
    String userId,
    String otherUserId,
    StreamController<List<Message>> broadcastController,
  ) async {
    try {
      print('[ChatService] 🔄 Инициализация stream для: $userId → $otherUserId');

      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userId, otherUserId);

      print('[ChatService] 📌 ChatId получен: $chatId');

      // Проверяем существует ли уже stream для этого чата
      if (_messageStreamControllers.containsKey(chatId)) {
        print('[ChatService] ♻️ Используется существующий stream');
        final existingController = _messageStreamControllers[chatId]!;

        // Перенаправляем данные из существующего stream в новый broadcast
        existingController.stream.listen(
          (messages) => broadcastController.add(messages),
          onError: (error) => broadcastController.addError(error),
        );
        return;
      }

      // Создаём новый StreamController для этого чата
      final controller = StreamController<List<Message>>.broadcast();
      _messageStreamControllers[chatId] = controller;

      print('[ChatService] ✨ Создан новый realtime stream для chatId: $chatId');

      // Перенаправляем данные в broadcast controller
      controller.stream.listen(
        (messages) => broadcastController.add(messages),
        onError: (error) => broadcastController.addError(error),
      );

      // Загружаем начальные сообщения
      await _loadInitialMessages(chatId, controller);

      // Подписываемся на realtime обновления (асинхронно)
      _subscribeToMessages(chatId, controller);
    } catch (e) {
      print('[ChatService] ❌ Ошибка создания stream: $e');
      broadcastController.addError(e);
    }
  }

  /// Подписка на realtime обновления сообщений
  Future<void> _subscribeToMessages(
      String chatId, StreamController<List<Message>> controller) async {
    try {
      print('[ChatService] 🔔 Подписка на realtime для chatId: $chatId');

      // ✅ ИСПРАВЛЕНИЕ: Подписываемся БЕЗ фильтра, проверяем внутри callback
      // ПРИЧИНА: PocketBase subscription с фильтром на RelationField может не срабатывать
      final unsubscribe = await _pb.collection('messages').subscribe(
        '*', // Слушаем ВСЕ события (без фильтра!)
        (e) {
          print('[ChatService] 🔥 Realtime событие получено!');
          print('  - action: ${e.action}');
          print('  - record.id: ${e.record?.id}');
          print('  - record.data: ${e.record?.data}');
          print('  - Ожидаемый chatId: $chatId');

          // Проверяем принадлежность сообщения к этому чату
          if (e.record != null) {
            // ✅ ПРОВЕРЯЕМ ОБА ВАРИАНТА НАЗВАНИЯ ПОЛЯ
            final recordChatId = e.record!.data['chatId'] as String?;
            final recordChatRoomId = e.record!.data['chatRoomId'] as String?;

            print('  - record.chatId: $recordChatId');
            print('  - record.chatRoomId: $recordChatRoomId');

            // Проверяем совпадение с любым из вариантов
            if (recordChatId == chatId || recordChatRoomId == chatId) {
              print('[ChatService] ✅ Сообщение относится к текущему чату! Перезагружаем...');
              // Перезагружаем все сообщения при изменении
              _loadInitialMessages(chatId, controller);
            } else {
              print('[ChatService] ⚠️ Сообщение НЕ относится к текущему чату (пропускаем)');
            }
          }
        },
        // ✅ УБРАЛИ ФИЛЬТР! Теперь слушаем ВСЕ сообщения, но проверяем chatId внутри callback
      );

      print('[ChatService] ✅ Подписка создана успешно');

      // Сохраняем unsubscribe функцию для очистки
      _subscriptions[chatId] = unsubscribe;
    } catch (e) {
      print('[ChatService] ❌ Ошибка подписки на realtime: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  /// Загрузить начальные сообщения и отправить в stream
  Future<void> _loadInitialMessages(
      String chatId, StreamController<List<Message>> controller) async {
    try {
      print('[ChatService] 📥 Загрузка сообщений для chatId: $chatId');

      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId"', // ✅ ИЗМЕНЕНО
            sort: '+created', // Старые сообщения первыми
            perPage: 500,
          );

      print('[ChatService] 📊 Найдено сообщений: ${result.items.length}');

      final messages = result.items
          .map((record) => Message.fromRecord(record, pb: _pb))
          .toList();

      if (!controller.isClosed) {
        controller.add(messages);
        print('[ChatService] ✅ Сообщения отправлены в stream (${messages.length} шт)');
      } else {
        print('[ChatService] ⚠️ Controller уже закрыт');
      }
    } catch (e) {
      print('[ChatService] ❌ Ошибка загрузки начальных сообщений: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  /// Отписаться от realtime обновлений для конкретного чата
  ///
  /// ВАЖНО: Вызывать при dispose() виджета чата!
  Future<void> unsubscribeFromMessages(String userId, String otherUserId) async {
    try {
      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userId, otherUserId);

      // Отписываемся от PocketBase
      final unsubscribe = _subscriptions.remove(chatId);
      if (unsubscribe != null) {
        unsubscribe();
        print('[ChatService] Отписка от realtime для: $chatId');
      }

      // Закрываем stream controller
      final controller = _messageStreamControllers.remove(chatId);
      if (controller != null) {
        controller.close();
        print('[ChatService] Stream controller закрыт для: $chatId');
      }
    } catch (e) {
      print('[ChatService] Ошибка отписки: $e');
    }
  }

  /// Получить сообщения чата (список, без реактивности)
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ❌ УДАЛЕНО: chatRoomId (строка)
  /// ✅ ДОБАВЛЕНО: получаем chatId через _getChatIdByUsers()
  /// ✅ ФИЛЬТР: 'chatId="..."' вместо 'chatRoomId="..."'
  ///
  /// ⚠️ РЕКОМЕНДАЦИЯ: Используйте getMessagesStream() для realtime обновлений!
  Future<List<Message>> getMessages(String userId, String otherUserId) async {
    try {
      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userId, otherUserId);

      // Запрос сообщений по chatId
      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId"', // ✅ ИЗМЕНЕНО
            sort: '+created', // Старые сообщения первыми
            perPage: 500, // Ограничение (можно добавить пагинацию)
          );

      // Преобразуем RecordModel в Message (передаём pb для построения fileUrl)
      return result.items
          .map((record) => Message.fromRecord(record, pb: _pb))
          .toList();
    } catch (e) {
      print('[ChatService] Ошибка получения сообщений: $e');
      return [];
    }
  }

  /// Получить последнее сообщение в чате
  Future<Map<String, dynamic>?> getLastMessage(
      String userID1, String userID2) async {
    try {
      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userID1, userID2);

      // Запрашиваем последнее сообщение
      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId"', // ✅ ИЗМЕНЕНО
            sort: '-created', // Новые первыми
            perPage: 1, // Только последнее
          );

      if (result.items.isEmpty) return null;

      final record = result.items.first;

      return {
        'message': record.data['message'] ?? '',
        'timestamp': DateTime.parse(record.created),
        'senderID': record.data['senderId'] ?? '',
      };
    } catch (e) {
      print('[ChatService] Ошибка получения последнего сообщения: $e');
      return null;
    }
  }

  /// Получить количество непрочитанных сообщений
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ✅ Используем chatId вместо chatRoomId
  /// ✅ Фильтр: 'chatId="..." && senderId="..." && isRead=false'
  Future<int> getUnreadCount(String userID1, String userID2) async {
    try {
      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userID1, userID2);

      // Подсчет непрочитанных через фильтр
      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId" && senderId="$userID2" && isRead=false', // ✅ ИЗМЕНЕНО
            perPage: 1, // Нам нужен только count
          );

      // totalItems - общее количество записей
      return result.totalItems;
    } catch (e) {
      print('[ChatService] Ошибка получения непрочитанных: $e');
      return 0;
    }
  }

  /// Пометить сообщения как прочитанные
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ✅ Используем chatId вместо chatRoomId
  Future<void> markMessagesAsRead(String userID1, String userID2) async {
    try {
      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userID1, userID2);

      // Получаем все непрочитанные сообщения от собеседника
      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId" && senderId="$userID2" && isRead=false', // ✅ ИЗМЕНЕНО
            perPage: 500, // Получаем все непрочитанные
          );

      // Помечаем каждое как прочитанное
      for (var record in result.items) {
        await _pb.collection('messages').update(
          record.id,
          body: {'isRead': true},
        );
      }

      print('[ChatService] Помечено прочитанными: ${result.items.length} сообщений');

      // ✅ ИСПРАВЛЕНИЕ: Обнуляем счетчик ВСЕГДА, даже если нет непрочитанных
      // Причина: пользователь мог уже прочитать сообщения, но счетчик еще не обнулился
      await _resetUnreadCount(chatId, userID1);
    } catch (e) {
      print('[ChatService] Ошибка пометки сообщений прочитанными: $e');
    }
  }

  /// ✅ НОВЫЙ МЕТОД: Обнулить счетчик непрочитанных для конкретного пользователя
  ///
  /// ПАРАМЕТРЫ:
  /// - chatId: ID записи в коллекции chats
  /// - userId: ID пользователя, для которого обнуляем счетчик
  ///
  /// ЛОГИКА:
  /// 1. Получаем метаданные чата
  /// 2. Определяем какой счетчик обнулить (user1 или user2)
  /// 3. Обновляем запись в chats
  Future<void> _resetUnreadCount(String chatId, String userId) async {
    try {
      print('[ChatService] 🔄 Обнуление счетчика для chatId: $chatId, userId: $userId');

      // Получаем текущую запись чата
      final record = await _pb.collection('chats').getOne(chatId);

      final user1Id = record.data['user1Id'] as String;
      final user2Id = record.data['user2Id'] as String;

      // Определяем какой счетчик обнулить
      final updateData = <String, dynamic>{};
      if (userId == user1Id) {
        updateData['unreadCountUser1'] = 0;
        print('[ChatService] Обнуляем unreadCountUser1');
      } else if (userId == user2Id) {
        updateData['unreadCountUser2'] = 0;
        print('[ChatService] Обнуляем unreadCountUser2');
      } else {
        print('[ChatService] ⚠️ userId не совпадает ни с user1Id, ни с user2Id!');
        return;
      }

      // Обновляем метаданные
      await _pb.collection('chats').update(chatId, body: updateData);

      print('[ChatService] ✅ Счетчик непрочитанных обнулён');
    } catch (e) {
      print('[ChatService] ❌ Ошибка обнуления счетчика: $e');
      // Не пробрасываем ошибку, это не критично
    }
  }

  /// Пожаловаться на пользователя
  ///
  /// ИЗМЕНЕНИЕ 11: Структура отчета изменена
  ///
  /// БЫЛО (Firestore):
  /// collection('Reports').add() - коллекция Reports
  ///
  /// СТАЛО (PocketBase):
  /// collection('reports').create() - коллекция reports (lowercase)
  Future<void> reportUser(String messageID, String userID) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      final report = {
        'reportedBy': currentUserId,
        'messageId': messageID, // ID сообщения
        'messageOwnerId': userID, // Владелец сообщения
        // timestamp создается автоматически через created поле в PocketBase
      };

      await _pb.collection('reports').create(body: report);

      print('[ChatService] Жалоба отправлена на пользователя: $userID');
    } catch (e) {
      print('[ChatService] Ошибка отправки жалобы: $e');
    }
  }

  /// Заблокировать пользователя
  ///
  /// ИЗМЕНЕНИЕ 12: Отдельная коллекция вместо подколлекции
  ///
  /// БЫЛО (Firestore - подколлекция):
  /// collection('Users').doc(currentUserId).collection('BlockedUser').doc(userID).set({})
  ///
  /// СТАЛО (PocketBase - отдельная коллекция):
  /// collection('blocked_users').create({userId: ..., blockedUserId: ...})
  Future<void> blockUser(String userID) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      // Создаем запись в коллекции blocked_users
      await _pb.collection('blocked_users').create(body: {
        'userId': currentUserId, // Кто блокирует
        'blockedUserId': userID, // Кого блокируют
      });

      print('[ChatService] Пользователь заблокирован: $userID');

      // ✅ УЛУЧШЕНИЕ: Инвалидируем кеш заблокированных
      _invalidateBlockedCache(currentUserId);

      notifyListeners(); // Уведомляем слушателей (ChangeNotifier)
    } catch (e) {
      print('[ChatService] Ошибка блокировки пользователя: $e');
    }
  }

  /// Разблокировать пользователя
  ///
  /// ИЗМЕНЕНИЕ 13: Удаление из отдельной коллекции
  ///
  /// БЫЛО (Firestore):
  /// collection('Users').doc(currentUserId).collection('BlockedUser').doc(blockedUserID).delete()
  ///
  /// СТАЛО (PocketBase):
  /// 1. Находим запись: filter: 'userId="..." && blockedUserId="..."'
  /// 2. Удаляем: delete(recordId)
  Future<void> unblockUser(String blockedUserID) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      // ИЗМЕНЕНИЕ 14: Сначала находим запись для удаления
      //
      // В PocketBase нужно знать ID записи для удаления
      // Ищем запись где userId=текущий && blockedUserId=разблокируемый
      final result = await _pb.collection('blocked_users').getList(
            filter: 'userId="$currentUserId" && blockedUserId="$blockedUserID"',
            perPage: 1,
          );

      if (result.items.isNotEmpty) {
        final recordId = result.items.first.id;
        await _pb.collection('blocked_users').delete(recordId);
        print('[ChatService] Пользователь разблокирован: $blockedUserID');

        // ✅ УЛУЧШЕНИЕ: Инвалидируем кеш заблокированных
        _invalidateBlockedCache(currentUserId);
      } else {
        print('[ChatService] Запись блокировки не найдена');
      }

      notifyListeners();
    } catch (e) {
      print('[ChatService] Ошибка разблокировки пользователя: $e');
    }
  }

  /// Получить список заблокированных пользователей
  ///
  /// ✅ УЛУЧШЕНИЕ: Future с кешированием
  Future<List<Map<String, dynamic>>> getBlockedUsers(String userID,
      {bool forceRefresh = false}) async {
    try {
      // Проверяем кеш (если не требуется принудительное обновление)
      if (!forceRefresh &&
          _cachedBlockedUsers.containsKey(userID) &&
          _isCacheValid(_blockedUsersCacheTime[userID])) {
        print('[ChatService] Используется кеш для getBlockedUsers()');
        return _cachedBlockedUsers[userID]!;
      }

      // Получаем записи блокировок
      final blockedRecords = await _pb.collection('blocked_users').getList(
            filter: 'userId="$userID"',
          );

      final blockedUserIds = blockedRecords.items
          .map((r) => r.data['blockedUserId'] as String)
          .toList();

      // Получаем данные заблокированных пользователей
      final List<Map<String, dynamic>> blockedUsers = [];

      for (var userId in blockedUserIds) {
        try {
          final userRecord = await _pb.collection('users').getOne(userId);
          blockedUsers.add({
            'uid': userRecord.id,
            'name': userRecord.data['name'] ?? '',
            'email': userRecord.data['email'] ?? '',
            'username': userRecord.data['username'] ?? '',
            'avatarUrl': userRecord.data['avatar'] ?? '',
          });
        } catch (e) {
          print(
              '[ChatService] Ошибка получения данных пользователя $userId: $e');
        }
      }

      // Сохраняем в кеш
      _cachedBlockedUsers[userID] = blockedUsers;
      _blockedUsersCacheTime[userID] = DateTime.now();
      print(
          '[ChatService] Кеш обновлён для getBlockedUsers() (${blockedUsers.length} заблокированных)');

      return blockedUsers;
    } catch (e) {
      print('[ChatService] Ошибка получения заблокированных пользователей: $e');
      return [];
    }
  }

  // ============================================================================
  // НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С КОЛЛЕКЦИЕЙ CHATS (метаданные чатов)
  // ============================================================================

  /// 🆕 ВСПОМОГАТЕЛЬНЫЙ МЕТОД: Получить ID чата по паре пользователей
  ///
  /// АРХИТЕКТУРА (НОВАЯ):
  /// - messages.chatId → chats.id (RelationField)
  /// - chats имеет unique constraint на (user1Id, user2Id)
  /// - НЕТ поля chatRoomId!
  ///
  /// ЛОГИКА:
  /// 1. Ищем чат по user1Id и user2Id (оба направления)
  /// 2. Если находим → возвращаем chats.id
  /// 3. Если не находим → создаём новый чат и возвращаем его id
  ///
  /// ВОЗВРАЩАЕТ:
  /// String - ID записи в коллекции chats (используется как chatId в messages)
  Future<String> _getChatIdByUsers(String user1Id, String user2Id) async {
    try {
      // Сортируем ID для консистентности (user1 всегда меньше user2)
      List<String> sortedIds = [user1Id, user2Id];
      sortedIds.sort();
      final sortedUser1 = sortedIds[0];
      final sortedUser2 = sortedIds[1];

      print('[ChatService] 🔍 Поиск чата между: $sortedUser1 и $sortedUser2');

      // Ищем чат по паре пользователей
      // Важно: ищем оба направления (user1+user2 или user2+user1)
      final existing = await _pb.collection('chats').getList(
            filter:
                '(user1Id="$sortedUser1" && user2Id="$sortedUser2") || (user1Id="$sortedUser2" && user2Id="$sortedUser1")',
            perPage: 1,
          );

      if (existing.items.isNotEmpty) {
        // Чат существует
        final chatId = existing.items.first.id;
        print('[ChatService] ✅ Чат найден: $chatId');
        return chatId;
      } else {
        // Чат не существует - создаём новый
        print('[ChatService] ✨ Создание нового чата...');

        final newChat = await _pb.collection('chats').create(body: {
          'user1Id': sortedUser1, // Меньший ID
          'user2Id': sortedUser2, // Больший ID
          'lastMessage': '', // Пустое сообщение при создании
          'lastMessageType': 'text',
          'lastSenderId': user1Id, // Текущий пользователь
          'lastTimestamp': DateTime.now().toIso8601String(),
          'unreadCountUser1': 0,
          'unreadCountUser2': 0,
        });

        print('[ChatService] ✅ Новый чат создан: ${newChat.id}');
        return newChat.id;
      }
    } catch (e) {
      print('[ChatService] ❌ Ошибка получения/создания chatId: $e');
      rethrow;
    }
  }

  /// Обновить метаданные чата после отправки сообщения
  ///
  /// НАЗНАЧЕНИЕ:
  /// После каждого отправленного сообщения обновляем запись в chats:
  /// - lastMessage, lastMessageType, lastSenderId, lastTimestamp
  /// - увеличиваем unreadCount для получателя
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ❌ УДАЛЕНО: поиск по chatRoomId
  /// ✅ ДОБАВЛЕНО: принимаем готовый chatId (record.id из chats)
  ///
  /// ЛОГИКА:
  /// 1. Получаем текущие метаданные чата по chatId
  /// 2. Увеличиваем unreadCount для получателя
  /// 3. Обновляем lastMessage, lastTimestamp и т.д.
  Future<void> _updateChatMetadata({
    required String chatId, // ✅ НОВОЕ: ID записи в chats (не chatRoomId!)
    required String lastMessage,
    required String lastMessageType,
    required String lastSenderId,
    required DateTime messageTimestamp,
  }) async {
    try {
      print('[ChatService] 🔄 Обновление метаданных чата: $chatId');

      // Получаем текущую запись чата
      final record = await _pb.collection('chats').getOne(chatId);

      final user1Id = record.data['user1Id'] as String;
      final user2Id = record.data['user2Id'] as String;

      // Определяем кто получатель (для увеличения unreadCount)
      final receiverId = lastSenderId == user1Id ? user2Id : user1Id;

      // Текущие счётчики
      int unreadUser1 = record.data['unreadCountUser1'] ?? 0;
      int unreadUser2 = record.data['unreadCountUser2'] ?? 0;

      // Увеличиваем счётчик получателя
      if (receiverId == user1Id) {
        unreadUser1++;
      } else {
        unreadUser2++;
      }

      // Обновляем метаданные
      await _pb.collection('chats').update(
        chatId,
        body: {
          'lastMessage': lastMessage,
          'lastMessageType': lastMessageType,
          'lastSenderId': lastSenderId,
          'lastTimestamp': messageTimestamp.toIso8601String(),
          'unreadCountUser1': unreadUser1,
          'unreadCountUser2': unreadUser2,
        },
      );

      print('[ChatService] ✅ Метаданные чата обновлены');
    } catch (e) {
      print('[ChatService] ❌ Ошибка обновления метаданных чата: $e');
      // Не пробрасываем ошибку, чтобы сообщение всё равно отправилось
    }
  }

  /// Получить список чатов из коллекции chats (БЫСТРО!)
  ///
  /// ПРЕИМУЩЕСТВА перед getActiveChats():
  /// ✅ 1 запрос вместо группировки сотен messages
  /// ✅ Встроенные счётчики непрочитанных
  /// ✅ Уже отсортировано по lastTimestamp
  /// ✅ КЕШИРОВАНИЕ на 30 секунд для снижения нагрузки
  ///
  /// ВОЗВРАЩАЕТ:
  /// List<Chat> - список чатов с метаданными
  Future<List<Chat>> getUserChatsFromMetadata({bool forceRefresh = false}) async {
    try {
      // Проверяем кеш (если не требуется принудительное обновление)
      if (!forceRefresh && _isCacheValid(_chatsCacheTime)) {
        print('[ChatService] Используется кеш для getUserChatsFromMetadata()');
        return _cachedChats!;
      }

      final currentUserId = Auth().getCurrentUid();

      // Получаем чаты где пользователь является участником
      final result = await _pb.collection('chats').getList(
            filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
            sort: '-lastTimestamp', // Новые первыми
            perPage: 100,
          );

      // Преобразуем в модели Chat
      final chats =
          result.items.map((record) => Chat.fromRecord(record)).toList();

      // Сохраняем в кеш
      _cachedChats = chats;
      _chatsCacheTime = DateTime.now();
      print(
          '[ChatService] Кеш обновлён для getUserChatsFromMetadata() (${chats.length} чатов)');

      return chats;
    } catch (e) {
      print('[ChatService] Ошибка получения чатов из метаданных: $e');
      return [];
    }
  }

  /// ✨ НОВЫЙ МЕТОД: Получить список чатов в реальном времени (realtime)
  ///
  /// ПРЕИМУЩЕСТВА:
  /// ✅ Автоматическое обновление при новых сообщениях БЕЗ мерцания экрана
  /// ✅ WebSocket подключение (эффективнее чем polling)
  /// ✅ Stream реактивный поток
  /// ✅ Нет необходимости в Timer.periodic
  ///
  /// ИСПОЛЬЗОВАНИЕ:
  /// ```dart
  /// final stream = chatService.getChatsStream();
  /// StreamBuilder(
  ///   stream: stream,
  ///   builder: (context, snapshot) { ... }
  /// );
  /// ```
  ///
  /// ВАЖНО: Вызвать unsubscribeFromChats() при dispose виджета!
  Stream<List<Chat>> getChatsStream() {
    final currentUserId = Auth().getCurrentUid();

    // Проверяем существует ли уже stream
    if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
      print('[ChatService] Используется существующий stream для списка чатов');
      return _chatsStreamController!.stream;
    }

    // Создаём новый StreamController
    _chatsStreamController = StreamController<List<Chat>>.broadcast();

    print('[ChatService] Создан новый realtime stream для списка чатов');

    // Загружаем начальные чаты
    _loadInitialChats(currentUserId);

    // Подписываемся на realtime обновления (асинхронно)
    _subscribeToChats(currentUserId);

    return _chatsStreamController!.stream;
  }

  /// Подписка на realtime обновления списка чатов
  Future<void> _subscribeToChats(String currentUserId) async {
    try {
      _chatsSubscription = await _pb.collection('chats').subscribe(
        '*', // Слушаем все события
        (e) {
          print(
              '[ChatService] Realtime событие для чатов: ${e.action} для записи ${e.record?.id}');

          // Проверяем принадлежность чата текущему пользователю
          if (e.record != null) {
            final user1Id = e.record!.data['user1Id'] as String?;
            final user2Id = e.record!.data['user2Id'] as String?;

            if (user1Id == currentUserId || user2Id == currentUserId) {
              // Перезагружаем список чатов при изменении
              _loadInitialChats(currentUserId);
            }
          }
        },
        filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
      );

      print('[ChatService] Подписка на realtime чатов создана');
    } catch (e) {
      print('[ChatService] Ошибка подписки на realtime чатов: $e');
      if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
        _chatsStreamController!.addError(e);
      }
    }
  }

  /// Загрузить начальный список чатов и отправить в stream
  Future<void> _loadInitialChats(String currentUserId) async {
    try {
      final result = await _pb.collection('chats').getList(
            filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
            sort: '-lastTimestamp', // Новые первыми
            perPage: 100,
          );

      final chats =
          result.items.map((record) => Chat.fromRecord(record)).toList();

      if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
        _chatsStreamController!.add(chats);
      }
    } catch (e) {
      print('[ChatService] Ошибка загрузки начального списка чатов: $e');
      if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
        _chatsStreamController!.addError(e);
      }
    }
  }

  /// Отписаться от realtime обновлений списка чатов
  ///
  /// ВАЖНО: Вызывать при dispose() виджета HomePage!
  void unsubscribeFromChats() {
    // Отписываемся от PocketBase
    _chatsSubscription?.call();
    _chatsSubscription = null;
    print('[ChatService] Отписка от realtime чатов');

    // Закрываем stream controller
    _chatsStreamController?.close();
    _chatsStreamController = null;
    print('[ChatService] Stream controller для чатов закрыт');
  }

  /// Сбросить счётчик непрочитанных для текущего пользователя
  ///
  /// ВЫЗЫВАЕТСЯ:
  /// Когда пользователь открывает чат (chat_page.dart)
  ///
  /// ИЗМЕНЕНИЯ (НОВАЯ АРХИТЕКТУРА):
  /// ❌ УДАЛЕНО: параметр chatRoomId
  /// ✅ ДОБАВЛЕНО: параметры userId и otherUserId
  /// ✅ Получаем chatId через _getChatIdByUsers()
  ///
  /// ЛОГИКА:
  /// 1. Получаем chatId по паре пользователей
  /// 2. Обнуляем счётчик для текущего пользователя (unreadCountUser1 или unreadCountUser2)
  /// 3. Помечаем сообщения как прочитанные (через существующий markMessagesAsRead)
  Future<void> resetUnreadCountInMetadata(String userId, String otherUserId) async {
    try {
      // ✅ Получаем chatId
      final chatId = await _getChatIdByUsers(userId, otherUserId);

      // Получаем запись чата
      final record = await _pb.collection('chats').getOne(chatId);

      final user1Id = record.data['user1Id'];
      final user2Id = record.data['user2Id'];

      // Определяем какой счётчик обнулять
      final updateData = <String, dynamic>{};
      if (userId == user1Id) {
        updateData['unreadCountUser1'] = 0;
      } else if (userId == user2Id) {
        updateData['unreadCountUser2'] = 0;
      }

      if (updateData.isNotEmpty) {
        await _pb.collection('chats').update(chatId, body: updateData);
        print('[ChatService] Счётчик непрочитанных сброшен для: $userId');

        // Также помечаем сообщения как прочитанные
        await markMessagesAsRead(userId, otherUserId);
      }
    } catch (e) {
      print('[ChatService] Ошибка сброса счётчика непрочитанных: $e');
    }
  }
}

/// ВАЖНЫЕ ЗАМЕЧАНИЯ:
///
/// 1. СТРУКТУРА ДАННЫХ:
/// - Firestore: вложенные коллекции (chat_room → messages)
/// - PocketBase: плоская структура (все messages в одной коллекции)
///
/// 2. РЕАКТИВНОСТЬ:
/// - Firestore: .snapshots() - автоматический Stream
/// - PocketBase: .getList() - Future (одноразовый запрос)
/// - Для реактивности в PocketBase: .subscribe() (можно добавить позже)
///
/// 3. СЧЕТЧИКИ:
/// - Firestore: FieldValue.increment() - атомарное увеличение
/// - PocketBase: считаем через filter (проще, но медленнее для больших чатов)
///
/// 4. БЛОКИРОВКИ:
/// - Firestore: Users/{uid}/BlockedUser/{blockedUid} (подколлекция)
/// - PocketBase: blocked_users коллекция с userId + blockedUserId
///
/// 5. chatRoomId:
/// - Генерируется одинаково: sort([uid1, uid2]).join('_')
/// - Это КРИТИЧЕСКИ ВАЖНО для работы чатов!
///
/// 6. ✅ РЕАЛИЗОВАННЫЕ УЛУЧШЕНИЯ:
/// ✅ Realtime через subscribe() - getMessagesStream()
/// ✅ Оптимизация getActiveChats() - getUserChatsFromMetadata() (two-table pattern)
/// ✅ Кеширование результатов (пользователи, чаты, заблокированные) - 5 мин TTL
/// ✅ Автоматическая инвалидация кеша при изменениях
/// ✅ Управление подписками через dispose()
///
/// 7. TODO для будущего:
/// - Добавить пагинацию для больших чатов (500+ сообщений)
/// - Оптимизировать загрузку изображений/аудио
/// - Добавить retry логику для сетевых ошибок
