import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:p7/models/user.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/cache_service.dart';
import 'pocketbase_service.dart';

class Databases {
  final _pb = PocketBaseService().client;

  Future<void> saveInfoInPocketBase({
    required String name,
    required String email,
    required DateTime birthDate,
    required String city,
    required String role,
  }) async {
    final uid = Auth().getCurrentUid();

    final userMap = {
      'name': name,
      'email': email,
      'birthDate': birthDate.toIso8601String(),
      'city': city,
      'role': role,
      'bio': '',
    };

    try {
      await _pb.collection('users').update(uid, body: userMap);

      debugPrint('[Databases] Профиль сохранен для пользователя: $uid');
    } on ClientException catch (e) {
      debugPrint('[Databases] Ошибка сохранения профиля: ${e.statusCode} - ${e.response}');
      rethrow;
    } catch (e) {
      debugPrint('[Databases] Неизвестная ошибка сохранения профиля: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getUserFromPocketBase(String uid) async {
    try {
      final record = await _pb.collection('users').getOne(uid);

      final user = UserProfile.fromRecord(record);

      String? fullAvatarUrl;
      final avatar = record.data['avatar'] as String?;
      if (avatar != null && avatar.isNotEmpty) {
        fullAvatarUrl = PocketBaseService().getFileUrl(
          record,
          avatar,
          thumb: '200x200',
        );
      }

      final result = user.copyWith(avatarUrl: fullAvatarUrl);

      CacheService().saveOtherUserProfile(result);

      return result;
    } on ClientException catch (e) {
      debugPrint('[Databases] Ошибка получения профиля: ${e.statusCode} - ${e.response}');
      if (e.statusCode == 404 || e.statusCode == 403) {
        return null;
      }
      debugPrint('[Databases] Пробуем кэш...');
      return await CacheService().getCachedOtherUserProfile(uid);
    } catch (e) {
      debugPrint('[Databases] Ошибка сети, пробуем кэш: $e');
      return await CacheService().getCachedOtherUserProfile(uid);
    }
  }

  Future<void> updateUserBio(String bio) async {
    String uid = Auth().getCurrentUid();

    try {
      await _pb.collection('users').update(uid, body: {'bio': bio});

      debugPrint('[Databases] Биография обновлена для: $uid');
    } on ClientException catch (e) {
      debugPrint('[Databases] Ошибка обновления биографии: ${e.statusCode} - ${e.response}');
    } catch (e) {
      debugPrint('[Databases] Неизвестная ошибка обновления биографии: $e');
    }
  }

  Future<List<UserProfile>> getTutorsList() async {
    try {
      final result = await _pb.collection('users').getList(
        filter: 'role="Репетитор"',
      );

      final tutors = result.items.map((record) {
        final user = UserProfile.fromRecord(record);

        String? fullAvatarUrl;
        final avatar = record.data['avatar'] as String?;
        if (avatar != null && avatar.isNotEmpty) {
          fullAvatarUrl = PocketBaseService().getFileUrl(
            record,
            avatar,
            thumb: '200x200',
          );
        }

        return user.copyWith(avatarUrl: fullAvatarUrl);
      }).toList();

      debugPrint('[Databases] Найдено репетиторов: ${tutors.length}');
      return tutors;
    } on ClientException catch (e) {
      debugPrint('[Databases] Ошибка получения репетиторов: ${e.statusCode} - ${e.response}');
      return [];
    } catch (e) {
      debugPrint('[Databases] Неизвестная ошибка получения репетиторов: $e');
      return [];
    }
  }

  Future<List<String>> getAllCities() async {
    try {
      final records = await _pb.collection('users').getFullList();

      final cities = records
          .map((record) => (record.data['city'] as String?) ?? '')
          .where((city) => city.isNotEmpty)
          .toSet()
          .toList();

      cities.sort();

      debugPrint('[Databases] Найдено городов: ${cities.length}');
      return cities;
    } on ClientException catch (e) {
      debugPrint('[Databases] Ошибка загрузки городов: ${e.statusCode} - ${e.response}');
      return [];
    } catch (e) {
      debugPrint('[Databases] Неизвестная ошибка загрузки городов: $e');
      return [];
    }
  }

  Future<void> updateUserProfile({
    String? name,
    String? city,
    String? role,
    String? bio,
  }) async {
    String uid = Auth().getCurrentUid();

    try {
      Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (city != null) updates['city'] = city;
      if (role != null) updates['role'] = role;
      if (bio != null) updates['bio'] = bio;

      if (updates.isNotEmpty) {
        await _pb.collection('users').update(uid, body: updates);

        debugPrint('[Databases] Профиль обновлен для: $uid, поля: ${updates.keys}');
      } else {
        debugPrint('[Databases] Нечего обновлять, все поля null');
      }
    } on ClientException catch (e) {
      debugPrint('[Databases] Ошибка обновления профиля: ${e.statusCode} - ${e.response}');
    } catch (e) {
      debugPrint('[Databases] Неизвестная ошибка обновления профиля: $e');
    }
  }
}
