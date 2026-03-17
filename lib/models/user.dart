import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String username;
  final DateTime birthDate;
  final String city;
  final String role;
  final String bio;
  final String? avatarUrl;
  final DateTime? lastSeen;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    required this.birthDate,
    required this.city,
    required this.role,
    required this.bio,
    this.avatarUrl,
    this.lastSeen,
  });

  factory UserProfile.fromRecord(RecordModel record) {
    final data = record.data;

    DateTime parsedBirthDate;
    try {
      final birthDateStr = data['birthDate'] as String?;
      if (birthDateStr != null && birthDateStr.isNotEmpty) {
        parsedBirthDate = DateTime.parse(birthDateStr);
      } else {
        parsedBirthDate = DateTime.now();
      }
    } catch (e) {
      debugPrint('[UserProfile] Ошибка парсинга birthDate: $e');
      parsedBirthDate = DateTime.now();
    }

    final avatar = data['avatar'] as String?;

    DateTime? lastSeen;
    try {
      final lastSeenStr = data['lastSeen'] as String?;
      if (lastSeenStr != null && lastSeenStr.isNotEmpty) {
        lastSeen = DateTime.parse(lastSeenStr);
      }
    } catch (_) {}

    return UserProfile(
      uid: record.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      username: data['username'] as String? ?? '',
      birthDate: parsedBirthDate,
      city: data['city'] as String? ?? 'Не указан',
      role: data['role'] as String? ?? 'Другое',
      bio: data['bio'] as String? ?? '',
      avatarUrl: avatar,
      lastSeen: lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'username': username,

      'birthDate': birthDate.toIso8601String(),

      'city': city,
      'role': role,
      'bio': bio,

      if (avatarUrl != null) 'avatar': avatarUrl,
    };
  }

  bool get isOnline {
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen!).inSeconds < 30;
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? username,
    DateTime? birthDate,
    String? city,
    String? role,
    String? bio,
    String? avatarUrl,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      birthDate: birthDate ?? this.birthDate,
      city: city ?? this.city,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
