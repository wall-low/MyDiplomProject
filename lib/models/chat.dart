import 'package:pocketbase/pocketbase.dart';

class Chat {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessage;
  final String lastMessageType;
  final String lastSenderId;
  final DateTime lastTimestamp;
  final int unreadCountUser1;
  final int unreadCountUser2;

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

  factory Chat.fromRecord(RecordModel record) {
    return Chat(
      id: record.id,
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

  int getUnreadCount(String userId) {
    if (userId == user1Id) return unreadCountUser1;
    if (userId == user2Id) return unreadCountUser2;
    return 0;
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

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
