import 'dart:async';
import 'package:flutter/material.dart';
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

    // Закрываем все stream controllers
    for (var controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

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
  /// ИЗМЕНЕНИЕ 5: Упрощенная структура - одна коллекция вместо двух
  ///
  /// БЫЛО (Firestore):
  /// 1. Обновляем chat_room/{chatRoomId} (метаданные)
  /// 2. Добавляем в chat_room/{chatRoomId}/messages (сообщение)
  ///
  /// СТАЛО (PocketBase):
  /// 1. Только создаем запись в messages (всё в одной коллекции)
  ///
  /// Коллекция messages содержит:
  /// - chatRoomId: идентификатор чата
  /// - senderId, receiverId: участники
  /// - message: текст сообщения
  /// - type: тип (text/image/audio)
  /// - isRead: прочитано ли
  Future<void> sendMessage(String receiverID, String message,
      {String type = 'text'}) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      // Генерируем chatRoomId (детерминированный для любой пары пользователей)
      List<String> ids = [currentUserId, receiverID];
      ids.sort(); // ВАЖНО: сортировка для одинакового ID
      String chatRoomId = ids.join('_');

      // Создаем объект сообщения
      final newMessage = Message(
        senderID: currentUserId,
        senderEmail: currentUserEmail,
        receiverID: receiverID,
        message: message,
        timestamp: DateTime.now(), // PocketBase использует DateTime, не Timestamp
        type: type,
      );

      // ИЗМЕНЕНИЕ 6: Создаем сообщение в PocketBase
      //
      // БЫЛО (Firestore - 2 операции):
      // 1. _firestore.collection("chat_room").doc(chatRoomId).set() - метаданные
      // 2. _firestore.collection("chat_room").doc(chatRoomId).collection("messages").add() - сообщение
      //
      // СТАЛО (PocketBase - 1 операция):
      // _pb.collection('messages').create() - только сообщение
      //
      // Все данные в одной записи:
      final messageData = {
        ...newMessage.toMap(),
        'chatRoomId': chatRoomId, // Добавляем chatRoomId для фильтрации
        'isRead': false,
      };

      print('[ChatService] 📤 Отправка сообщения в чат: $chatRoomId');
      print('[ChatService]   От: $currentUserId');
      print('[ChatService]   Кому: $receiverID');

      final createdMessage = await _pb.collection('messages').create(body: messageData);

      print('[ChatService] ✅ Сообщение отправлено: ${createdMessage.id}');

      // НОВОЕ: Обновляем метаданные чата в коллекции chats
      await _createOrUpdateChatRoom(
        chatRoomId: chatRoomId,
        user1Id: ids[0], // ids уже отсортированы выше
        user2Id: ids[1],
        lastMessage: message,
        lastMessageType: type,
        lastSenderId: currentUserId,
      );

      // ✅ УЛУЧШЕНИЕ: Инвалидируем кеш чатов
      _invalidateChatsCache();
    } catch (e) {
      print('[ChatService] Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  /// Отправка изображения
  ///
  /// Аналогично sendMessage, но с type = 'image'
  Future<void> sendMessageWithImage({
    required String receiverId,
    required String imageUrl,
  }) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      String chatRoomId = ids.join('_');

      final msg = Message(
        senderID: currentUserId,
        senderEmail: currentUserEmail,
        receiverID: receiverId,
        message: imageUrl, // URL изображения
        timestamp: DateTime.now(),
        type: 'image',
      );

      final messageData = {
        ...msg.toMap(),
        'chatRoomId': chatRoomId,
        'isRead': false,
      };

      await _pb.collection('messages').create(body: messageData);

      print('[ChatService] Изображение отправлено в чат: $chatRoomId');

      // НОВОЕ: Обновляем метаданные чата
      await _createOrUpdateChatRoom(
        chatRoomId: chatRoomId,
        user1Id: ids[0], // ids уже отсортированы выше
        user2Id: ids[1],
        lastMessage: '📷 Фото', // Превью для изображения
        lastMessageType: 'image',
        lastSenderId: currentUserId,
      );

      // ✅ УЛУЧШЕНИЕ: Инвалидируем кеш чатов
      _invalidateChatsCache();
    } catch (e) {
      print('[ChatService] Ошибка отправки изображения: $e');
      rethrow;
    }
  }

  /// Отправка аудио
  ///
  /// Аналогично sendMessage, но с type = 'audio'
  Future<void> sendMessageWithAudio({
    required String receiverId,
    required String audioUrl,
  }) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      String chatRoomId = ids.join('_');

      final msg = Message(
        senderID: currentUserId,
        senderEmail: currentUserEmail,
        receiverID: receiverId,
        message: audioUrl, // URL аудио
        timestamp: DateTime.now(),
        type: 'audio',
      );

      final messageData = {
        ...msg.toMap(),
        'chatRoomId': chatRoomId,
        'isRead': false,
      };

      await _pb.collection('messages').create(body: messageData);

      print('[ChatService] Аудио отправлено в чат: $chatRoomId');

      // НОВОЕ: Обновляем метаданные чата
      await _createOrUpdateChatRoom(
        chatRoomId: chatRoomId,
        user1Id: ids[0], // ids уже отсортированы выше
        user2Id: ids[1],
        lastMessage: '🎵 Аудио', // Превью для аудио
        lastMessageType: 'audio',
        lastSenderId: currentUserId,
      );

      // ✅ УЛУЧШЕНИЕ: Инвалидируем кеш чатов
      _invalidateChatsCache();
    } catch (e) {
      print('[ChatService] Ошибка отправки аудио: $e');
      rethrow;
    }
  }

  // ============================================================================
  // REALTIME SUBSCRIPTIONS ДЛЯ СООБЩЕНИЙ
  // ============================================================================

  /// ✨ НОВЫЙ МЕТОД: Получить сообщения чата в реальном времени (realtime)
  ///
  /// ПРЕИМУЩЕСТВА:
  /// ✅ Автоматическое обновление при новых сообщениях
  /// ✅ WebSocket подключение (эффективнее чем polling)
  /// ✅ Stream реактивный поток как в Firestore
  ///
  /// ИСПОЛЬЗОВАНИЕ:
  /// ```dart
  /// final stream = chatService.getMessagesStream(userId, otherUserId);
  /// StreamBuilder(
  ///   stream: stream,
  ///   builder: (context, snapshot) { ... }
  /// );
  /// ```
  ///
  /// ВАЖНО: Вызвать unsubscribeFromMessages() при dispose виджета!
  Stream<List<Message>> getMessagesStream(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Проверяем существует ли уже stream для этого чата
    if (_messageStreamControllers.containsKey(chatRoomId)) {
      print('[ChatService] Используется существующий stream для: $chatRoomId');
      return _messageStreamControllers[chatRoomId]!.stream;
    }

    // Создаём новый StreamController
    final controller = StreamController<List<Message>>.broadcast();
    _messageStreamControllers[chatRoomId] = controller;

    print('[ChatService] Создан новый realtime stream для: $chatRoomId');

    // Загружаем начальные сообщения
    _loadInitialMessages(chatRoomId, controller);

    // Подписываемся на realtime обновления (асинхронно)
    _subscribeToMessages(chatRoomId, controller);

    return controller.stream;
  }

  /// Подписка на realtime обновления сообщений
  Future<void> _subscribeToMessages(
      String chatRoomId, StreamController<List<Message>> controller) async {
    try {
      final unsubscribe = await _pb.collection('messages').subscribe(
        '*', // Слушаем все события
        (e) {
          print(
              '[ChatService] Realtime событие: ${e.action} для записи ${e.record?.id}');

          // Проверяем принадлежность сообщения к этому чату
          if (e.record != null) {
            final recordChatRoomId = e.record!.data['chatRoomId'] as String?;
            if (recordChatRoomId == chatRoomId) {
              // Перезагружаем все сообщения при изменении
              _loadInitialMessages(chatRoomId, controller);
            }
          }
        },
        filter: 'chatRoomId="$chatRoomId"',
      );

      // Сохраняем unsubscribe функцию для очистки
      _subscriptions[chatRoomId] = unsubscribe;
    } catch (e) {
      print('[ChatService] Ошибка подписки на realtime: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  /// Загрузить начальные сообщения и отправить в stream
  Future<void> _loadInitialMessages(
      String chatRoomId, StreamController<List<Message>> controller) async {
    try {
      final result = await _pb.collection('messages').getList(
            filter: 'chatRoomId="$chatRoomId"',
            sort: '+created', // Старые сообщения первыми
            perPage: 500,
          );

      final messages =
          result.items.map((record) => Message.fromRecord(record)).toList();

      if (!controller.isClosed) {
        controller.add(messages);
      }
    } catch (e) {
      print('[ChatService] Ошибка загрузки начальных сообщений: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  /// Отписаться от realtime обновлений для конкретного чата
  ///
  /// ВАЖНО: Вызывать при dispose() виджета чата!
  void unsubscribeFromMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Отписываемся от PocketBase
    final unsubscribe = _subscriptions.remove(chatRoomId);
    if (unsubscribe != null) {
      unsubscribe();
      print('[ChatService] Отписка от realtime для: $chatRoomId');
    }

    // Закрываем stream controller
    final controller = _messageStreamControllers.remove(chatRoomId);
    if (controller != null) {
      controller.close();
      print('[ChatService] Stream controller закрыт для: $chatRoomId');
    }
  }

  /// Получить сообщения чата (список, без реактивности)
  ///
  /// БЫЛО (Firestore):
  /// Stream<QuerySnapshot> - реактивный поток, автоматически обновляется
  ///
  /// СТАЛО (PocketBase):
  /// Future<List<Message>> - одноразовый запрос
  ///
  /// ⚠️ РЕКОМЕНДАЦИЯ: Используйте getMessagesStream() для realtime обновлений!
  Future<List<Message>> getMessages(String userId, String otherUserId) async {
    try {
      List<String> ids = [userId, otherUserId];
      ids.sort();
      String chatRoomId = ids.join('_');

      // ИЗМЕНЕНИЕ 7: Запрос сообщений по chatRoomId
      //
      // БЫЛО (Firestore):
      // _firestore.collection("chat_room").doc(chatRoomId).collection("messages")
      //   .orderBy("timestamp", descending: false).snapshots()
      //
      // СТАЛО (PocketBase):
      // _pb.collection('messages').getList(
      //   filter: 'chatRoomId="$chatRoomId"',
      //   sort: '+created'  // + = ascending (старые первыми)
      // )
      //
      // PocketBase фильтры:
      // - filter: 'chatRoomId="..."' - SQL-like синтаксис
      // - sort: '+created' - сортировка по дате создания (по возрастанию)
      //   '+' = ascending (старые → новые)
      //   '-' = descending (новые → старые)
      final result = await _pb.collection('messages').getList(
            filter: 'chatRoomId="$chatRoomId"',
            sort: '+created', // Старые сообщения первыми
            perPage: 500, // Ограничение (можно добавить пагинацию)
          );

      // Преобразуем RecordModel в Message
      return result.items.map((record) => Message.fromRecord(record)).toList();
    } catch (e) {
      print('[ChatService] Ошибка получения сообщений: $e');
      return [];
    }
  }

  /// Получить последнее сообщение в чате
  Future<Map<String, dynamic>?> getLastMessage(
      String userID1, String userID2) async {
    try {
      List<String> ids = [userID1, userID2];
      ids.sort();
      String chatRoomId = ids.join('_');

      // Запрашиваем последнее сообщение (сортировка по убыванию, limit 1)
      final result = await _pb.collection('messages').getList(
            filter: 'chatRoomId="$chatRoomId"',
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
  /// ИЗМЕНЕНИЕ 8: Подсчет через фильтр вместо счетчика
  ///
  /// БЫЛО (Firestore):
  /// Счетчик хранился в документе chat_room:
  /// - unread_count_user1
  /// - unread_count_user2
  /// Увеличивался через FieldValue.increment(1)
  ///
  /// СТАЛО (PocketBase):
  /// Считаем через фильтр:
  /// filter: 'chatRoomId="..." && senderId="other" && isRead=false'
  ///
  /// ПОЧЕМУ:
  /// PocketBase не поддерживает FieldValue.increment()
  /// Проще считать непрочитанные сообщения через запрос
  Future<int> getUnreadCount(String userID1, String userID2) async {
    try {
      List<String> ids = [userID1, userID2];
      ids.sort();
      String chatRoomId = ids.join('_');

      // ИЗМЕНЕНИЕ 9: Подсчет непрочитанных через фильтр
      //
      // Получаем сообщения где:
      // - chatRoomId соответствует чату
      // - senderId = собеседник (не мы)
      // - isRead = false
      final result = await _pb.collection('messages').getList(
            filter: 'chatRoomId="$chatRoomId" && senderId="$userID2" && isRead=false',
            perPage: 1, // Нам нужен только count, не сами сообщения
          );

      // totalItems - общее количество записей (не только на текущей странице)
      return result.totalItems;
    } catch (e) {
      print('[ChatService] Ошибка получения непрочитанных: $e');
      return 0;
    }
  }

  /// Пометить сообщения как прочитанные
  ///
  /// ИЗМЕНЕНИЕ 10: Обновление через batch-запрос
  ///
  /// БЫЛО (Firestore):
  /// 1. Запрос непрочитанных сообщений
  /// 2. Обновление каждого через doc.reference.update()
  /// 3. Сброс счетчика в chat_room
  ///
  /// СТАЛО (PocketBase):
  /// 1. Запрос непрочитанных сообщений
  /// 2. Обновление каждого через update()
  /// (счетчика нет, он считается динамически)
  Future<void> markMessagesAsRead(String userID1, String userID2) async {
    try {
      List<String> ids = [userID1, userID2];
      ids.sort();
      String chatRoomId = ids.join('_');

      // Получаем все непрочитанные сообщения от собеседника
      final result = await _pb.collection('messages').getList(
            filter: 'chatRoomId="$chatRoomId" && senderId="$userID2" && isRead=false',
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
    } catch (e) {
      print('[ChatService] Ошибка пометки сообщений прочитанными: $e');
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

  /// Создать или обновить метаданные чата после отправки сообщения
  ///
  /// НАЗНАЧЕНИЕ:
  /// После каждого отправленного сообщения обновляем запись в chats:
  /// - lastMessage, lastMessageType, lastSenderId, lastTimestamp
  /// - увеличиваем unreadCount для получателя
  ///
  /// ЛОГИКА:
  /// 1. Проверяем существует ли чат (getList с filter по chatRoomId)
  /// 2. Если существует → update()
  /// 3. Если не существует → create()
  Future<void> _createOrUpdateChatRoom({
    required String chatRoomId,
    required String user1Id,
    required String user2Id,
    required String lastMessage,
    required String lastMessageType,
    required String lastSenderId,
  }) async {
    try {
      print('[ChatService] 🔍 Проверка существования чата: $chatRoomId');

      // Проверяем существует ли чат
      final existing = await _pb.collection('chats').getList(
            filter: 'chatRoomId="$chatRoomId"',
            perPage: 1,
          );

      print('[ChatService] 📊 Найдено записей: ${existing.items.length}');

      // Определяем кто получатель (для увеличения unreadCount)
      final receiverId = lastSenderId == user1Id ? user2Id : user1Id;

      if (existing.items.isNotEmpty) {
        // ЧАТ СУЩЕСТВУЕТ → обновляем
        final record = existing.items.first;

        // Текущие счётчики
        int unreadUser1 = record.data['unreadCountUser1'] ?? 0;
        int unreadUser2 = record.data['unreadCountUser2'] ?? 0;

        // Увеличиваем счётчик получателя
        if (receiverId == user1Id) {
          unreadUser1++;
        } else {
          unreadUser2++;
        }

        print('[ChatService] 🔄 Обновление существующего чата...');

        await _pb.collection('chats').update(
          record.id,
          body: {
            'lastMessage': lastMessage,
            'lastMessageType': lastMessageType,
            'lastSenderId': lastSenderId,
            'lastTimestamp': DateTime.now().toIso8601String(),
            'unreadCountUser1': unreadUser1,
            'unreadCountUser2': unreadUser2,
          },
        );

        print('[ChatService] ✅ Метаданные чата обновлены: $chatRoomId');
      } else {
        // ЧАТ НЕ СУЩЕСТВУЕТ → создаём
        print('[ChatService] ✨ Создание нового чата...');
        print('[ChatService]   user1Id: $user1Id');
        print('[ChatService]   user2Id: $user2Id');
        print('[ChatService]   receiverId: $receiverId');

        final newChat = await _pb.collection('chats').create(body: {
          'chatRoomId': chatRoomId,
          'user1Id': user1Id,
          'user2Id': user2Id,
          'lastMessage': lastMessage,
          'lastMessageType': lastMessageType,
          'lastSenderId': lastSenderId,
          'lastTimestamp': DateTime.now().toIso8601String(),
          // Счётчик для получателя = 1, для отправителя = 0
          'unreadCountUser1': receiverId == user1Id ? 1 : 0,
          'unreadCountUser2': receiverId == user2Id ? 1 : 0,
        });

        print('[ChatService] ✅ Метаданные чата созданы: ${newChat.id}');
      }
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

  /// Сбросить счётчик непрочитанных для текущего пользователя
  ///
  /// ВЫЗЫВАЕТСЯ:
  /// Когда пользователь открывает чат (chat_page.dart)
  ///
  /// ЛОГИКА:
  /// 1. Находим запись чата в chats
  /// 2. Обнуляем счётчик для текущего пользователя (unreadCountUser1 или unreadCountUser2)
  /// 3. Помечаем сообщения как прочитанные (через существующий markMessagesAsRead)
  Future<void> resetUnreadCountInMetadata(String chatRoomId) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      // Находим чат
      final existing = await _pb.collection('chats').getList(
            filter: 'chatRoomId="$chatRoomId"',
            perPage: 1,
          );

      if (existing.items.isEmpty) {
        print('[ChatService] Чат не найден для сброса счётчика: $chatRoomId');
        return;
      }

      final record = existing.items.first;
      final user1Id = record.data['user1Id'];
      final user2Id = record.data['user2Id'];

      // Определяем какой счётчик обнулять
      final updateData = <String, dynamic>{};
      if (currentUserId == user1Id) {
        updateData['unreadCountUser1'] = 0;
      } else if (currentUserId == user2Id) {
        updateData['unreadCountUser2'] = 0;
      }

      if (updateData.isNotEmpty) {
        await _pb.collection('chats').update(record.id, body: updateData);
        print('[ChatService] Счётчик непрочитанных сброшен для: $currentUserId');

        // Также помечаем сообщения как прочитанные
        final otherUserId = currentUserId == user1Id ? user2Id : user1Id;
        await markMessagesAsRead(currentUserId, otherUserId);
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
