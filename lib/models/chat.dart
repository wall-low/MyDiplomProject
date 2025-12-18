import 'package:pocketbase/pocketbase.dart';

/// Модель чата (метаданные чата)
///
/// ОБНОВЛЕНО (НОВАЯ АРХИТЕКТУРА):
/// ❌ УДАЛЕНО: поле chatRoomId (строка "uid1_uid2")
/// ✅ Теперь используется только id (PK из chats)
///
/// Хранит информацию о последнем сообщении и счётчики непрочитанных
/// для быстрого отображения списка чатов на главной странице
class Chat {
  final String id; // ← PK из chats (используется как chatId в messages)
  final String user1Id;
  final String user2Id;
  final String? lastMessage; // Текст последнего сообщения или null для фото/аудио
  final String lastMessageType; // "text" | "image" | "audio"
  final String lastSenderId;
  final DateTime lastTimestamp;
  final int unreadCountUser1; // Непрочитанные для user1
  final int unreadCountUser2; // Непрочитанные для user2

  Chat({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage,
    required this.lastMessageType,
    required this.lastSenderId,
    required this.lastTimestamp,
    this.unreadCountUser1 = 0,
    this.unreadCountUser2 = 0,
  });

  /// Создание Chat из RecordModel (PocketBase)
  factory Chat.fromRecord(RecordModel record) {
    return Chat(
      id: record.id, // ← Это chatId!
      user1Id: record.data['user1Id'] ?? '',
      user2Id: record.data['user2Id'] ?? '',
      lastMessage: record.data['lastMessage'],
      lastMessageType: record.data['lastMessageType'] ?? 'text',
      lastSenderId: record.data['lastSenderId'] ?? '',
      lastTimestamp: DateTime.parse(record.data['lastTimestamp']),
      unreadCountUser1: record.data['unreadCountUser1'] ?? 0,
      unreadCountUser2: record.data['unreadCountUser2'] ?? 0,
    );
  }

  /// Преобразование в Map для отправки в PocketBase
  Map<String, dynamic> toMap() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastSenderId': lastSenderId,
      'lastTimestamp': lastTimestamp.toIso8601String(),
      'unreadCountUser1': unreadCountUser1,
      'unreadCountUser2': unreadCountUser2,
    };
  }

  /// Получить количество непрочитанных для конкретного пользователя
  int getUnreadCount(String userId) {
    if (userId == user1Id) return unreadCountUser1;
    if (userId == user2Id) return unreadCountUser2;
    return 0;
  }

  /// Получить ID собеседника для текущего пользователя
  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

  /// Получить превью последнего сообщения для отображения в списке
  String getLastMessagePreview() {
    switch (lastMessageType) {
      case 'text':
        return lastMessage ?? '';
      case 'image':
        return '📷 Фото';
      case 'audio':
        return '🎵 Аудио';
      default:
        return '';
    }
  }

  /// Копирование с изменением полей
  Chat copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    String? lastMessage,
    String? lastMessageType,
    String? lastSenderId,
    DateTime? lastTimestamp,
    int? unreadCountUser1,
    int? unreadCountUser2,
  }) {
    return Chat(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      unreadCountUser1: unreadCountUser1 ?? this.unreadCountUser1,
      unreadCountUser2: unreadCountUser2 ?? this.unreadCountUser2,
    );
  }
}
