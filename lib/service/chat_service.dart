import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:p7/models/message.dart';
import 'package:p7/models/chat.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/cache_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';

class ChatService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  List<Map<String, dynamic>>? _cachedUserList;
  DateTime? _userListCacheTime;
  static const _cacheValidDuration = Duration(minutes: 5);

  final Map<String, List<Map<String, dynamic>>> _cachedBlockedUsers = {};
  final Map<String, DateTime> _blockedUsersCacheTime = {};

  List<Chat>? _cachedChats;
  DateTime? _chatsCacheTime;

  final Map<String, StreamController<List<Message>>> _messageStreamControllers =
      {};
  final Map<String, UnsubscribeFunc> _subscriptions = {};

  StreamController<List<Chat>>? _chatsStreamController;
  UnsubscribeFunc? _chatsSubscription;

  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheValidDuration;
  }

  void clearCache() {
    _cachedUserList = null;
    _userListCacheTime = null;
    _cachedBlockedUsers.clear();
    _blockedUsersCacheTime.clear();
    _cachedChats = null;
    _chatsCacheTime = null;
    debugPrint('[ChatService] Кеш очищен');
    notifyListeners();
  }

  void _invalidateChatsCache() {
    _cachedChats = null;
    _chatsCacheTime = null;
  }

  void invalidateUserCache() {
    _cachedUserList = null;
    _userListCacheTime = null;
  }

  void _invalidateBlockedCache(String userId) {
    _cachedBlockedUsers.remove(userId);
    _blockedUsersCacheTime.remove(userId);
  }

  @override
  void dispose() {
    for (var unsubscribe in _subscriptions.values) {
      unsubscribe();
    }
    _subscriptions.clear();

    for (var controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

    _chatsSubscription?.call();
    _chatsStreamController?.close();

    super.dispose();
  }

  Future<List<Map<String, dynamic>>> getUserList({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && _isCacheValid(_userListCacheTime)) {
        debugPrint('[ChatService] Используется кеш для getUserList()');
        return _cachedUserList!;
      }

      final currentUserId = Auth().getCurrentUid();

      final records = await _pb.collection('users').getFullList();

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

      _cachedUserList = userList;
      _userListCacheTime = DateTime.now();
      debugPrint('[ChatService] Кеш обновлён для getUserList() (${userList.length} пользователей)');

      return userList;
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения пользователей: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUsersExcludingBlocked() async {
    try {
      final currentUserId = Auth().getCurrentUid();

      final blockedRecords = await _pb.collection('blocked_users').getList(
            filter: 'userId="$currentUserId"',
          );

      final blockedUserIds =
          blockedRecords.items.map((r) => r.data['blockedUserId'] as String).toList();

      final allUsers = await _pb.collection('users').getFullList();

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
      debugPrint('[ChatService] Ошибка получения пользователей (без блокировок): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveChats() async {
    try {
      final currentUserId = Auth().getCurrentUid();

      final messages = await _pb.collection('messages').getList(
            filter: 'senderId="$currentUserId" || receiverId="$currentUserId"',
            sort: '-created',
            perPage: 500,
          );

      final Map<String, RecordModel> lastMessageByChat = {};
      for (var msg in messages.items) {
        final chatRoomId = msg.data['chatRoomId'] as String;
        if (!lastMessageByChat.containsKey(chatRoomId)) {
          lastMessageByChat[chatRoomId] = msg;
        }
      }

      final blockedRecords = await _pb.collection('blocked_users').getList(
            filter: 'userId="$currentUserId"',
          );
      final blockedUserIds =
          blockedRecords.items.map((r) => r.data['blockedUserId'] as String).toList();

      final chatsList = <Map<String, dynamic>>[];

      for (var entry in lastMessageByChat.entries) {
        final chatRoomId = entry.key;
        final lastMsg = entry.value;

        final participants = chatRoomId.split('_');
        final otherUserId =
            participants[0] == currentUserId ? participants[1] : participants[0];

        if (blockedUserIds.contains(otherUserId)) continue;

        try {
          final userRecord = await _pb.collection('users').getOne(otherUserId);

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
          debugPrint('[ChatService] Ошибка получения данных пользователя $otherUserId: $e');
          continue;
        }
      }

      chatsList.sort((a, b) {
        final aTime = DateTime.parse(a['lastTimestamp']);
        final bTime = DateTime.parse(b['lastTimestamp']);
        return bTime.compareTo(aTime);
      });

      return chatsList;
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения активных чатов: $e');
      return [];
    }
  }

  Future<void> sendMessage(String receiverID, String message,
      {String type = 'text'}) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      debugPrint('[ChatService] 📤 Отправка сообщения от: $currentUserId → $receiverID');

      final chatId = await _getChatIdByUsers(currentUserId, receiverID);
      if (chatId == null) {
        throw Exception('Не удалось создать чат между $currentUserId и $receiverID');
      }

      final messageTimestamp = DateTime.now();
      final newMessage = Message(
        senderID: currentUserId,
        senderEmail: currentUserEmail,
        receiverID: receiverID,
        message: message,
        timestamp: messageTimestamp,
        type: type,
      );

      final messageData = {
        ...newMessage.toMap(),
        'chatId': chatId,
        'isRead': false,
      };

      final createdMessage = await _pb.collection('messages').create(body: messageData);

      debugPrint('[ChatService] ✅ Сообщение отправлено: ${createdMessage.id}');

      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: message,
        lastMessageType: type,
        lastSenderId: currentUserId,
        messageTimestamp: messageTimestamp,
      );

      _invalidateChatsCache();
    } catch (e) {
      debugPrint('[ChatService] Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  Future<void> sendMessageWithImage({
    required String receiverId,
    required String filePath,
  }) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      debugPrint('[ChatService] 📤 Отправка изображения от: $currentUserId → $receiverId');
      debugPrint('[ChatService] 📁 Путь к файлу: $filePath');

      final chatId = await _getChatIdByUsers(currentUserId, receiverId);
      if (chatId == null) {
        throw Exception('Не удалось создать чат между $currentUserId и $receiverId');
      }

      final messageTimestamp = DateTime.now();

      final body = <String, dynamic>{
        'chatId': chatId,
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'message': '',
        'type': 'image',
        'isRead': false,
        'timestamp': messageTimestamp.toIso8601String(),
      };

      String imageMimeType = 'image/jpeg';
      if (filePath.endsWith('.png')) {
        imageMimeType = 'image/png';
      } else if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
        imageMimeType = 'image/jpeg';
      } else if (filePath.endsWith('.gif')) {
        imageMimeType = 'image/gif';
      } else if (filePath.endsWith('.webp')) {
        imageMimeType = 'image/webp';
      }

      debugPrint('[ChatService] 🖼️ Detected image MIME type: $imageMimeType');

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

      debugPrint('[ChatService] ✅ Изображение отправлено: ${createdMessage.id}');

      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: '📷 Фото',
        lastMessageType: 'image',
        lastSenderId: currentUserId,
        messageTimestamp: messageTimestamp,
      );

      _invalidateChatsCache();
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка отправки изображения: $e');
      rethrow;
    }
  }

  Future<void> sendMessageWithAudio({
    required String receiverId,
    required String filePath,
  }) async {
    try {
      final currentUserId = Auth().getCurrentUid();
      final currentUserEmail = Auth().getCurrentUser()?.data['email'] ?? '';

      debugPrint('[ChatService] 📤 Отправка аудио от: $currentUserId → $receiverId');
      debugPrint('[ChatService] 📁 Путь к файлу: $filePath');

      final chatId = await _getChatIdByUsers(currentUserId, receiverId);
      if (chatId == null) {
        throw Exception('Не удалось создать чат между $currentUserId и $receiverId');
      }

      final messageTimestamp = DateTime.now();

      final body = <String, dynamic>{
        'chatId': chatId,
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'message': '',
        'type': 'audio',
        'isRead': false,
        'timestamp': messageTimestamp.toIso8601String(),
      };

      String mimeType = 'audio/x-m4a';
      if (filePath.endsWith('.m4a')) {
        mimeType = 'audio/x-m4a';
      } else if (filePath.endsWith('.aac')) {
        mimeType = 'audio/aac';
      } else if (filePath.endsWith('.wav')) {
        mimeType = 'audio/wav';
      } else if (filePath.endsWith('.mp3')) {
        mimeType = 'audio/mpeg';
      } else if (filePath.endsWith('.oga') || filePath.endsWith('.ogg')) {
        mimeType = 'audio/ogg';
      } else if (filePath.endsWith('.mp4')) {
        mimeType = 'audio/mp4';
      }

      final fileBytes = await File(filePath).readAsBytes();
      final fileName = filePath.split('/').last;

      final file = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: http.MediaType.parse(mimeType),
      );

      debugPrint('[ChatService] 🎵 Отправка аудио: $fileName (${mimeType})');

      final createdMessage = await _pb.collection('messages').create(
        body: body,
        files: [file],
      );

      debugPrint('[ChatService] ✅ Аудио отправлено: ${createdMessage.id}');
      debugPrint('[ChatService] 📋 Детали сообщения:');
      debugPrint('  - file: ${createdMessage.data['file']}');
      debugPrint('  - type: ${createdMessage.data['type']}');
      debugPrint('  - message: "${createdMessage.data['message']}"');

      if (createdMessage.data['file'] != null) {
        try {
          final testUrl = _pb.getFileUrl(createdMessage, createdMessage.data['file']).toString();
          debugPrint('[ChatService] 🔗 Построенный URL: $testUrl');
        } catch (e) {
          debugPrint('[ChatService] ❌ Ошибка построения URL: $e');
        }
      } else {
        debugPrint('[ChatService] ⚠️ Поле file пустое! Файл не загружен в PocketBase.');
      }

      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: '🎵 Аудио',
        lastMessageType: 'audio',
        lastSenderId: currentUserId,
        messageTimestamp: messageTimestamp,
      );

      _invalidateChatsCache();
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка отправки аудио: $e');
      rethrow;
    }
  }

  Stream<List<Message>> getMessagesStream(String userId, String otherUserId) {
    final broadcastController = StreamController<List<Message>>.broadcast();

    _initializeMessageStream(userId, otherUserId, broadcastController);

    return broadcastController.stream;
  }

  Future<void> _initializeMessageStream(
    String userId,
    String otherUserId,
    StreamController<List<Message>> broadcastController,
  ) async {
    try {
      debugPrint('[ChatService] 🔄 Инициализация stream для: $userId → $otherUserId');

      final chatId = await _getChatIdByUsers(userId, otherUserId, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] ⚠️ Чат не существует, отправляем пустой список сообщений');
        broadcastController.add([]);
        return;
      }

      debugPrint('[ChatService] 📌 ChatId получен: $chatId');

      if (_messageStreamControllers.containsKey(chatId)) {
        debugPrint('[ChatService] ♻️ Используется существующий stream');
        final existingController = _messageStreamControllers[chatId]!;

        existingController.stream.listen(
          (messages) => broadcastController.add(messages),
          onError: (error) => broadcastController.addError(error),
        );
        return;
      }

      final controller = StreamController<List<Message>>.broadcast();
      _messageStreamControllers[chatId] = controller;

      debugPrint('[ChatService] ✨ Создан новый realtime stream для chatId: $chatId');

      controller.stream.listen(
        (messages) => broadcastController.add(messages),
        onError: (error) => broadcastController.addError(error),
      );

      await _loadInitialMessages(chatId, controller);

      _subscribeToMessages(chatId, controller);
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка создания stream: $e');
      broadcastController.addError(e);
    }
  }

  Future<void> _subscribeToMessages(
      String chatId, StreamController<List<Message>> controller) async {
    try {
      debugPrint('[ChatService] 🔔 Подписка на realtime для chatId: $chatId');

      final unsubscribe = await _pb.collection('messages').subscribe(
        '*',
        (e) {
          debugPrint('[ChatService] 🔥 Realtime событие получено!');
          debugPrint('  - action: ${e.action}');
          debugPrint('  - record.id: ${e.record?.id}');
          debugPrint('  - record.data: ${e.record?.data}');
          debugPrint('  - Ожидаемый chatId: $chatId');

          if (e.record != null) {
            final recordChatId = e.record!.data['chatId'] as String?;
            final recordChatRoomId = e.record!.data['chatRoomId'] as String?;

            debugPrint('  - record.chatId: $recordChatId');
            debugPrint('  - record.chatRoomId: $recordChatRoomId');

            if (recordChatId == chatId || recordChatRoomId == chatId) {
              debugPrint('[ChatService] ✅ Сообщение относится к текущему чату! Перезагружаем...');
              _loadInitialMessages(chatId, controller);
            } else {
              debugPrint('[ChatService] ⚠️ Сообщение НЕ относится к текущему чату (пропускаем)');
            }
          }
        },
      );

      debugPrint('[ChatService] ✅ Подписка создана успешно');

      _subscriptions[chatId] = unsubscribe;
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка подписки на realtime: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _loadInitialMessages(
      String chatId, StreamController<List<Message>> controller) async {
    try {
      debugPrint('[ChatService] 📥 Загрузка сообщений для chatId: $chatId');

      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId"',
            sort: '+created',
            perPage: 500,
          );

      debugPrint('[ChatService] 📊 Найдено сообщений: ${result.items.length}');

      final messages = result.items
          .map((record) => Message.fromRecord(record, pb: _pb))
          .toList();

      if (!controller.isClosed) {
        controller.add(messages);
        debugPrint('[ChatService] ✅ Сообщения отправлены в stream (${messages.length} шт)');
      } else {
        debugPrint('[ChatService] ⚠️ Controller уже закрыт');
      }
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка загрузки начальных сообщений: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> unsubscribeFromMessages(String userId, String otherUserId) async {
    try {
      final chatId = await _getChatIdByUsers(userId, otherUserId, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] Чат не существует, нечего отписывать');
        return;
      }

      final unsubscribe = _subscriptions.remove(chatId);
      if (unsubscribe != null) {
        unsubscribe();
        debugPrint('[ChatService] Отписка от realtime для: $chatId');
      }

      final controller = _messageStreamControllers.remove(chatId);
      if (controller != null) {
        controller.close();
        debugPrint('[ChatService] Stream controller закрыт для: $chatId');
      }
    } catch (e) {
      debugPrint('[ChatService] Ошибка отписки: $e');
    }
  }

  Future<List<Message>> getMessages(String userId, String otherUserId) async {
    try {
      final chatId = await _getChatIdByUsers(userId, otherUserId, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] Чат не существует, возвращаем пустой список');
        return [];
      }

      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId"',
            sort: '+created',
            perPage: 500,
          );

      return result.items
          .map((record) => Message.fromRecord(record, pb: _pb))
          .toList();
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения сообщений: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLastMessage(
      String userID1, String userID2) async {
    try {
      final chatId = await _getChatIdByUsers(userID1, userID2, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] Чат не существует, нет последнего сообщения');
        return null;
      }

      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId"',
            sort: '-created',
            perPage: 1,
          );

      if (result.items.isEmpty) return null;

      final record = result.items.first;

      return {
        'message': record.data['message'] ?? '',
        'timestamp': DateTime.parse(record.created),
        'senderID': record.data['senderId'] ?? '',
      };
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения последнего сообщения: $e');
      return null;
    }
  }

  Future<int> getUnreadCount(String userID1, String userID2) async {
    try {
      final chatId = await _getChatIdByUsers(userID1, userID2, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] Чат не существует, нет непрочитанных');
        return 0;
      }

      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId" && senderId="$userID2" && isRead=false',
            perPage: 1,
          );

      return result.totalItems;
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения непрочитанных: $e');
      return 0;
    }
  }

  Future<void> markMessagesAsRead(String userID1, String userID2) async {
    try {
      final chatId = await _getChatIdByUsers(userID1, userID2, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] Чат не существует, нечего помечать прочитанным');
        return;
      }

      final result = await _pb.collection('messages').getList(
            filter: 'chatId="$chatId" && senderId="$userID2" && isRead=false',
            perPage: 500,
          );

      for (var record in result.items) {
        await _pb.collection('messages').update(
          record.id,
          body: {'isRead': true},
        );
      }

      debugPrint('[ChatService] Помечено прочитанными: ${result.items.length} сообщений');

      await _resetUnreadCount(chatId, userID1);
    } catch (e) {
      debugPrint('[ChatService] Ошибка пометки сообщений прочитанными: $e');
    }
  }

  Future<void> _resetUnreadCount(String chatId, String userId) async {
    try {
      debugPrint('[ChatService] 🔄 Обнуление счетчика для chatId: $chatId, userId: $userId');

      final record = await _pb.collection('chats').getOne(chatId);

      final user1Id = record.data['user1Id'] as String;
      final user2Id = record.data['user2Id'] as String;

      final updateData = <String, dynamic>{};
      if (userId == user1Id) {
        updateData['unreadCountUser1'] = 0;
        debugPrint('[ChatService] Обнуляем unreadCountUser1');
      } else if (userId == user2Id) {
        updateData['unreadCountUser2'] = 0;
        debugPrint('[ChatService] Обнуляем unreadCountUser2');
      } else {
        debugPrint('[ChatService] ⚠️ userId не совпадает ни с user1Id, ни с user2Id!');
        return;
      }

      await _pb.collection('chats').update(chatId, body: updateData);

      debugPrint('[ChatService] ✅ Счетчик непрочитанных обнулён');
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка обнуления счетчика: $e');
    }
  }

  Future<void> reportUser(String messageID, String userID) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      final report = {
        'reportedBy': currentUserId,
        'messageId': messageID,
        'messageOwnerId': userID,
      };

      await _pb.collection('reports').create(body: report);

      debugPrint('[ChatService] Жалоба отправлена на пользователя: $userID');
    } catch (e) {
      debugPrint('[ChatService] Ошибка отправки жалобы: $e');
    }
  }

  Future<void> blockUser(String userID) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      await _pb.collection('blocked_users').create(body: {
        'userId': currentUserId,
        'blockedUserId': userID,
      });

      debugPrint('[ChatService] Пользователь заблокирован: $userID');

      _invalidateBlockedCache(currentUserId);

      notifyListeners();
    } catch (e) {
      debugPrint('[ChatService] Ошибка блокировки пользователя: $e');
    }
  }

  Future<void> unblockUser(String blockedUserID) async {
    try {
      final currentUserId = Auth().getCurrentUid();

      final result = await _pb.collection('blocked_users').getList(
            filter: 'userId="$currentUserId" && blockedUserId="$blockedUserID"',
            perPage: 1,
          );

      if (result.items.isNotEmpty) {
        final recordId = result.items.first.id;
        await _pb.collection('blocked_users').delete(recordId);
        debugPrint('[ChatService] Пользователь разблокирован: $blockedUserID');

        _invalidateBlockedCache(currentUserId);
      } else {
        debugPrint('[ChatService] Запись блокировки не найдена');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[ChatService] Ошибка разблокировки пользователя: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers(String userID,
      {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh &&
          _cachedBlockedUsers.containsKey(userID) &&
          _isCacheValid(_blockedUsersCacheTime[userID])) {
        debugPrint('[ChatService] Используется кеш для getBlockedUsers()');
        return _cachedBlockedUsers[userID]!;
      }

      final blockedRecords = await _pb.collection('blocked_users').getList(
            filter: 'userId="$userID"',
          );

      final blockedUserIds = blockedRecords.items
          .map((r) => r.data['blockedUserId'] as String)
          .toList();

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
          debugPrint(
              '[ChatService] Ошибка получения данных пользователя $userId: $e');
        }
      }

      _cachedBlockedUsers[userID] = blockedUsers;
      _blockedUsersCacheTime[userID] = DateTime.now();
      debugPrint(
          '[ChatService] Кеш обновлён для getBlockedUsers() (${blockedUsers.length} заблокированных)');

      return blockedUsers;
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения заблокированных пользователей: $e');
      return [];
    }
  }

  Future<String?> _getChatIdByUsers(String user1Id, String user2Id, {bool createIfNotExists = true}) async {
    try {
      List<String> sortedIds = [user1Id, user2Id];
      sortedIds.sort();
      final sortedUser1 = sortedIds[0];
      final sortedUser2 = sortedIds[1];

      debugPrint('[ChatService] 🔍 Поиск чата между: $sortedUser1 и $sortedUser2');

      final existing = await _pb.collection('chats').getList(
            filter:
                '(user1Id="$sortedUser1" && user2Id="$sortedUser2") || (user1Id="$sortedUser2" && user2Id="$sortedUser1")',
            perPage: 1,
          );

      if (existing.items.isNotEmpty) {
        final chatId = existing.items.first.id;
        debugPrint('[ChatService] ✅ Чат найден: $chatId');
        return chatId;
      } else {
        if (createIfNotExists) {
          debugPrint('[ChatService] ✨ Создание нового чата...');

          final newChat = await _pb.collection('chats').create(body: {
            'user1Id': sortedUser1,
            'user2Id': sortedUser2,
            'lastMessage': '',
            'lastMessageType': 'text',
            'lastSenderId': user1Id,
            'lastTimestamp': DateTime.now().toIso8601String(),
            'unreadCountUser1': 0,
            'unreadCountUser2': 0,
          });

          debugPrint('[ChatService] ✅ Новый чат создан: ${newChat.id}');
          return newChat.id;
        } else {
          debugPrint('[ChatService] ⚠️ Чат не найден и createIfNotExists = false, возвращаем null');
          return null;
        }
      }
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка получения/создания chatId: $e');
      rethrow;
    }
  }

  Future<void> _updateChatMetadata({
    required String chatId,
    required String lastMessage,
    required String lastMessageType,
    required String lastSenderId,
    required DateTime messageTimestamp,
  }) async {
    try {
      debugPrint('[ChatService] 🔄 Обновление метаданных чата: $chatId');

      final record = await _pb.collection('chats').getOne(chatId);

      final user1Id = record.data['user1Id'] as String;
      final user2Id = record.data['user2Id'] as String;

      final receiverId = lastSenderId == user1Id ? user2Id : user1Id;

      int unreadUser1 = record.data['unreadCountUser1'] ?? 0;
      int unreadUser2 = record.data['unreadCountUser2'] ?? 0;

      if (receiverId == user1Id) {
        unreadUser1++;
      } else {
        unreadUser2++;
      }

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

      debugPrint('[ChatService] ✅ Метаданные чата обновлены');
    } catch (e) {
      debugPrint('[ChatService] ❌ Ошибка обновления метаданных чата: $e');
    }
  }

  Future<List<Chat>> getUserChatsFromMetadata({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && _isCacheValid(_chatsCacheTime)) {
        debugPrint('[ChatService] Используется кеш для getUserChatsFromMetadata()');
        return _cachedChats!;
      }

      final currentUserId = Auth().getCurrentUid();

      final result = await _pb.collection('chats').getList(
            filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
            sort: '-lastTimestamp',
            perPage: 100,
          );

      final chats =
          result.items.map((record) => Chat.fromRecord(record)).toList();

      _cachedChats = chats;
      _chatsCacheTime = DateTime.now();
      debugPrint(
          '[ChatService] Кеш обновлён для getUserChatsFromMetadata() (${chats.length} чатов)');

      return chats;
    } catch (e) {
      debugPrint('[ChatService] Ошибка получения чатов из метаданных: $e');
      return [];
    }
  }

  Stream<List<Chat>> getChatsStream() {
    final currentUserId = Auth().getCurrentUid();

    if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
      debugPrint('[ChatService] Используется существующий stream для списка чатов');
      return _chatsStreamController!.stream;
    }

    _chatsStreamController = StreamController<List<Chat>>.broadcast();

    debugPrint('[ChatService] Создан новый realtime stream для списка чатов');

    _loadInitialChats(currentUserId);

    _subscribeToChats(currentUserId);

    return _chatsStreamController!.stream;
  }

  Future<void> _subscribeToChats(String currentUserId) async {
    try {
      _chatsSubscription = await _pb.collection('chats').subscribe(
        '*',
        (e) {
          debugPrint(
              '[ChatService] Realtime событие для чатов: ${e.action} для записи ${e.record?.id}');

          if (e.record != null) {
            final user1Id = e.record!.data['user1Id'] as String?;
            final user2Id = e.record!.data['user2Id'] as String?;

            if (user1Id == currentUserId || user2Id == currentUserId) {
              _loadInitialChats(currentUserId);
            }
          }
        },
        filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
      );

      debugPrint('[ChatService] Подписка на realtime чатов создана');
    } catch (e) {
      debugPrint('[ChatService] Ошибка подписки на realtime чатов: $e');
      if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
        _chatsStreamController!.addError(e);
      }
    }
  }

  Future<void> _loadInitialChats(String currentUserId) async {
    try {
      final result = await _pb.collection('chats').getList(
            filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
            sort: '-lastTimestamp',
            perPage: 100,
          );

      final chats =
          result.items.map((record) => Chat.fromRecord(record)).toList();

      CacheService().saveChats(chats);

      if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
        _chatsStreamController!.add(chats);
      }
    } catch (e) {
      debugPrint('[ChatService] Ошибка загрузки чатов, пробуем кэш: $e');
      final cached = await CacheService().getCachedChats();
      if (_chatsStreamController != null && !_chatsStreamController!.isClosed) {
        if (cached.isNotEmpty) {
          _chatsStreamController!.add(cached);
        } else {
          _chatsStreamController!.addError(e);
        }
      }
    }
  }

  void unsubscribeFromChats() {
    _chatsSubscription?.call();
    _chatsSubscription = null;
    debugPrint('[ChatService] Отписка от realtime чатов');

    _chatsStreamController?.close();
    _chatsStreamController = null;
    debugPrint('[ChatService] Stream controller для чатов закрыт');
  }

  Future<void> resetUnreadCountInMetadata(String userId, String otherUserId) async {
    try {
      final chatId = await _getChatIdByUsers(userId, otherUserId, createIfNotExists: false);

      if (chatId == null) {
        debugPrint('[ChatService] Чат не существует, нечего обнулять');
        return;
      }

      final record = await _pb.collection('chats').getOne(chatId);

      final user1Id = record.data['user1Id'];
      final user2Id = record.data['user2Id'];

      final updateData = <String, dynamic>{};
      if (userId == user1Id) {
        updateData['unreadCountUser1'] = 0;
      } else if (userId == user2Id) {
        updateData['unreadCountUser2'] = 0;
      }

      if (updateData.isNotEmpty) {
        await _pb.collection('chats').update(chatId, body: updateData);
        debugPrint('[ChatService] Счётчик непрочитанных сброшен для: $userId');

        await markMessagesAsRead(userId, otherUserId);
      }
    } catch (e) {
      debugPrint('[ChatService] Ошибка сброса счётчика непрочитанных: $e');
    }
  }
}
