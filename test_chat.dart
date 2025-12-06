/// Скрипт для проверки работы chat_service.dart
///
/// Запуск: dart run test_chat.dart
///
/// Проверяет:
/// 1. Подключение к PocketBase
/// 2. Отправку сообщения
/// 3. Создание метаданных чата

import 'package:pocketbase/pocketbase.dart';

void main() async {
  print('=== ТЕСТ CHAT SERVICE ===\n');

  // Подключение к PocketBase
  final pb = PocketBase('http://localhost:8090');
  print('✓ Подключились к PocketBase');

  try {
    // 1. Проверяем коллекции
    print('\n1. Проверка коллекций:');

    final collections = ['users', 'messages', 'chats'];
    for (var name in collections) {
      try {
        final result = await pb.collection(name).getList(perPage: 1);
        print('  ✓ Коллекция "$name" существует (${result.totalItems} записей)');
      } catch (e) {
        print('  ✗ Ошибка коллекции "$name": $e');
      }
    }

    // 2. Проверяем пользователей
    print('\n2. Проверка пользователей:');
    final users = await pb.collection('users').getList(perPage: 5);

    if (users.items.isEmpty) {
      print('  ✗ Нет пользователей! Создайте пользователей через регистрацию.');
      return;
    }

    print('  ✓ Найдено ${users.totalItems} пользователей');
    for (var user in users.items.take(3)) {
      print('    - ${user.data['username']} (${user.id})');
    }

    // 3. Тест отправки сообщения (ИМИТАЦИЯ)
    print('\n3. Тест создания сообщения:');

    if (users.items.length < 2) {
      print('  ✗ Нужно минимум 2 пользователя для чата');
      return;
    }

    final user1 = users.items[0];
    final user2 = users.items[1];

    List<String> ids = [user1.id, user2.id];
    ids.sort();
    String chatRoomId = ids.join('_');

    print('  Отправитель: ${user1.data['username']}');
    print('  Получатель: ${user2.data['username']}');
    print('  chatRoomId: $chatRoomId');

    // Создаём тестовое сообщение
    try {
      final message = await pb.collection('messages').create(body: {
        'chatRoomId': chatRoomId,
        'senderId': user1.id,
        'senderEmail': user1.data['email'],
        'receiverId': user2.id,
        'message': 'Тестовое сообщение от скрипта',
        'type': 'text',
        'isRead': false,
      });

      print('  ✓ Сообщение создано: ${message.id}');
    } catch (e) {
      print('  ✗ Ошибка создания сообщения: $e');
      print('\n📝 ПРОБЛЕМА: API Rules для коллекции "messages" блокируют создание!');
      print('   Решение: Откройте PocketBase Admin UI → Collections → messages → API Rules');
      print('   createRule должно быть: senderId = @request.auth.id');
      print('   ИЛИ для теста поставьте: "" (пустое = разрешено всем)');
      return;
    }

    // 4. Тест создания метаданных чата
    print('\n4. Тест создания метаданных чата:');

    try {
      final chat = await pb.collection('chats').create(body: {
        'chatRoomId': chatRoomId,
        'user1Id': ids[0],
        'user2Id': ids[1],
        'lastMessage': 'Тестовое сообщение от скрипта',
        'lastMessageType': 'text',
        'lastSenderId': user1.id,
        'lastTimestamp': DateTime.now().toIso8601String(),
        'unreadCountUser1': 0,
        'unreadCountUser2': 1,
      });

      print('  ✓ Метаданные чата созданы: ${chat.id}');
    } catch (e) {
      print('  ✗ Ошибка создания метаданных: $e');
      print('\n📝 ПРОБЛЕМА: API Rules для коллекции "chats" блокируют создание!');
      print('   Решение: Откройте PocketBase Admin UI → Collections → chats → API Rules');
      print('   createRule должно быть: user1Id = @request.auth.id || user2Id = @request.auth.id');
      print('   ИЛИ для теста поставьте: "" (пустое = разрешено всем)');
      return;
    }

    // 5. Проверка результата
    print('\n5. Проверка результата:');

    final messagesCount = await pb.collection('messages').getList(perPage: 1);
    final chatsCount = await pb.collection('chats').getList(perPage: 1);

    print('  ✓ Сообщений в базе: ${messagesCount.totalItems}');
    print('  ✓ Чатов в базе: ${chatsCount.totalItems}');

    print('\n✅ ВСЕ ПРОВЕРКИ ПРОШЛИ УСПЕШНО!');
    print('   Теперь попробуйте отправить сообщение из приложения.');

  } catch (e, stackTrace) {
    print('\n❌ ОШИБКА: $e');
    print('Stack trace: $stackTrace');
  }
}
