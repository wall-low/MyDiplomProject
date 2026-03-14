import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/chat.dart';

/// Простой кэш-сервис для офлайн-доступа
///
/// Сохраняет данные в SharedPreferences:
/// - Профиль текущего пользователя
/// - Список чатов (последние сообщения)
/// - Профили собеседников (для отображения имён в чатах)
///
/// Данные обновляются при каждом успешном запросе к серверу.
/// При отсутствии интернета — показываются сохранённые данные.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const _keyUserProfile = 'cache_user_profile';
  static const _keyChats = 'cache_chats';
  static const _keyUserProfiles = 'cache_user_profiles'; // профили собеседников

  // --- Профиль текущего пользователя ---

  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'uid': profile.uid,
      'name': profile.name,
      'email': profile.email,
      'username': profile.username,
      'birthDate': profile.birthDate.toIso8601String(),
      'city': profile.city,
      'role': profile.role,
      'bio': profile.bio,
      'avatarUrl': profile.avatarUrl,
    });
    await prefs.setString(_keyUserProfile, json);
  }

  Future<UserProfile?> getCachedUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyUserProfile);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return UserProfile(
        uid: data['uid'] ?? '',
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        username: data['username'] ?? '',
        birthDate: DateTime.tryParse(data['birthDate'] ?? '') ?? DateTime.now(),
        city: data['city'] ?? '',
        role: data['role'] ?? '',
        bio: data['bio'] ?? '',
        avatarUrl: data['avatarUrl'],
      );
    } catch (_) {
      return null;
    }
  }

  // --- Профили собеседников (для чат-листа) ---

  Future<void> saveOtherUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyUserProfiles);
    final Map<String, dynamic> profiles =
        existing != null ? jsonDecode(existing) : {};

    profiles[profile.uid] = {
      'uid': profile.uid,
      'name': profile.name,
      'email': profile.email,
      'username': profile.username,
      'birthDate': profile.birthDate.toIso8601String(),
      'city': profile.city,
      'role': profile.role,
      'bio': profile.bio,
      'avatarUrl': profile.avatarUrl,
    };

    await prefs.setString(_keyUserProfiles, jsonEncode(profiles));
  }

  Future<UserProfile?> getCachedOtherUserProfile(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyUserProfiles);
    if (existing == null) return null;

    try {
      final profiles = jsonDecode(existing) as Map<String, dynamic>;
      final data = profiles[uid];
      if (data == null) return null;

      return UserProfile(
        uid: data['uid'] ?? '',
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        username: data['username'] ?? '',
        birthDate: DateTime.tryParse(data['birthDate'] ?? '') ?? DateTime.now(),
        city: data['city'] ?? '',
        role: data['role'] ?? '',
        bio: data['bio'] ?? '',
        avatarUrl: data['avatarUrl'],
      );
    } catch (_) {
      return null;
    }
  }

  // --- Список чатов ---

  Future<void> saveChats(List<Chat> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = chats.map((c) => {
      'id': c.id,
      'user1Id': c.user1Id,
      'user2Id': c.user2Id,
      'lastMessage': c.lastMessage,
      'lastMessageType': c.lastMessageType,
      'lastSenderId': c.lastSenderId,
      'lastTimestamp': c.lastTimestamp.toIso8601String(),
      'unreadCountUser1': c.unreadCountUser1,
      'unreadCountUser2': c.unreadCountUser2,
    }).toList();
    await prefs.setString(_keyChats, jsonEncode(jsonList));
  }

  Future<List<Chat>> getCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyChats);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list.map((data) => Chat(
        id: data['id'] ?? '',
        user1Id: data['user1Id'] ?? '',
        user2Id: data['user2Id'] ?? '',
        lastMessage: data['lastMessage'],
        lastMessageType: data['lastMessageType'] ?? 'text',
        lastSenderId: data['lastSenderId'] ?? '',
        lastTimestamp: DateTime.tryParse(data['lastTimestamp'] ?? '') ?? DateTime.now(),
        unreadCountUser1: data['unreadCountUser1'] ?? 0,
        unreadCountUser2: data['unreadCountUser2'] ?? 0,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Очистка кэша (при выходе) ---

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserProfile);
    await prefs.remove(_keyChats);
    await prefs.remove(_keyUserProfiles);
  }
}
