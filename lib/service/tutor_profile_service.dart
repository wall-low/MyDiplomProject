import 'package:flutter/foundation.dart';
import '../models/tutor_profile.dart';
import 'pocketbase_service.dart';

class TutorProfileService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  Future<TutorProfile?> createTutorProfile({
    required String userId,
    List<String> subjects = const [],
    double? priceMin,
    double? priceMax,
    int? experience,
    String? education,
    List<String> lessonFormat = const [],
    String? payoutCardLast4,
  }) async {
    try {
      final exists = await checkIfTutorProfileExists(userId);
      if (exists) {
        debugPrint('[TutorProfileService] ❌ Профиль для userId=$userId уже существует');
        return null;
      }

      final body = {
        'userId': userId,
        'subjects': subjects,
        if (priceMin != null) 'priceMin': priceMin,
        if (priceMax != null) 'priceMax': priceMax,
        if (experience != null) 'experience': experience,
        if (education != null && education.isNotEmpty) 'education': education,
        'lessonFormat': lessonFormat,
        'rating': 0.0,
        'totalPaidLessons': 0,
        'isNewbie': true,
        if (payoutCardLast4 != null && payoutCardLast4.isNotEmpty)
          'payoutCardLast4': payoutCardLast4,
      };

      debugPrint('[TutorProfileService] 📝 Создание профиля: $body');

      final record = await _pb.collection('tutor_profiles').create(body: body);

      debugPrint('[TutorProfileService] ✅ Профиль создан: ${record.id}');

      notifyListeners();

      return TutorProfile.fromRecord(record);
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка создания профиля: $e');
      return null;
    }
  }

  Future<TutorProfile?> getTutorProfileByUserId(String userId) async {
    try {
      final result = await _pb.collection('tutor_profiles').getList(
            filter: 'userId="$userId"',
            perPage: 1,
          );

      if (result.items.isEmpty) {
        debugPrint('[TutorProfileService] ℹ️ Профиль для userId=$userId не найден');
        return null;
      }

      final profile = TutorProfile.fromRecord(result.items.first);
      debugPrint('[TutorProfileService] ✅ Профиль найден: ${profile.id}');

      return profile;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка получения профиля: $e');
      return null;
    }
  }

  Future<TutorProfile?> getTutorProfileById(String profileId) async {
    try {
      final record = await _pb.collection('tutor_profiles').getOne(profileId);
      return TutorProfile.fromRecord(record);
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка получения профиля по ID: $e');
      return null;
    }
  }

  Future<TutorProfile?> updateTutorProfile(
    String profileId,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('[TutorProfileService] 📝 Обновление профиля $profileId: $updates');

      final record = await _pb.collection('tutor_profiles').update(
            profileId,
            body: updates,
          );

      debugPrint('[TutorProfileService] ✅ Профиль обновлён');

      notifyListeners();

      return TutorProfile.fromRecord(record);
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка обновления профиля: $e');
      return null;
    }
  }

  Future<bool> deleteTutorProfile(String profileId) async {
    try {
      await _pb.collection('tutor_profiles').delete(profileId);

      debugPrint('[TutorProfileService] ✅ Профиль удалён: $profileId');

      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка удаления профиля: $e');
      return false;
    }
  }

  Future<bool> checkIfTutorProfileExists(String userId) async {
    try {
      final result = await _pb.collection('tutor_profiles').getList(
            filter: 'userId="$userId"',
            perPage: 1,
          );

      return result.items.isNotEmpty;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка проверки существования: $e');
      return false;
    }
  }

  Future<bool> updateRating({
    required String profileId,
    required double newRating,
    required int totalPaidLessons,
    required bool isNewbie,
  }) async {
    try {
      await _pb.collection('tutor_profiles').update(
        profileId,
        body: {
          'rating': newRating,
          'totalPaidLessons': totalPaidLessons,
          'isNewbie': isNewbie,
        },
      );

      debugPrint(
          '[TutorProfileService] ✅ Рейтинг: $newRating, занятий: $totalPaidLessons, новичок: $isNewbie');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка обновления рейтинга: $e');
      return false;
    }
  }

  Future<bool> incrementPaidLessons(String profileId) async {
    try {
      final profile = await getTutorProfileById(profileId);
      if (profile == null) return false;

      final newTotal = profile.totalPaidLessons + 1;

      await _pb.collection('tutor_profiles').update(
        profileId,
        body: {
          'totalPaidLessons': newTotal,
          'lastPaidLessonDate': DateTime.now().toIso8601String(),
          'isNewbie': false,
        },
      );

      debugPrint('[TutorProfileService] ✅ Счётчик занятий увеличен: $newTotal');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка увеличения счётчика: $e');
      return false;
    }
  }

  Future<List<TutorProfile>> searchTutors({
    List<String>? subjects,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? lessonFormat,
  }) async {
    try {
      List<String> filters = [];

      if (subjects != null && subjects.isNotEmpty) {
        final subjectFilters =
            subjects.map((s) => 'subjects ?~ "$s"').toList();
        filters.add('(${subjectFilters.join(' || ')})');
      }

      if (minPrice != null) {
        filters.add('priceMin >= $minPrice');
      }
      if (maxPrice != null) {
        filters.add('priceMax <= $maxPrice');
      }

      if (minRating != null) {
        filters.add('rating >= $minRating');
      }

      if (lessonFormat != null) {
        filters.add('lessonFormat ?~ "$lessonFormat"');
      }

      final filterStr = filters.isNotEmpty ? filters.join(' && ') : '';

      debugPrint('[TutorProfileService] 🔍 Поиск репетиторов: $filterStr');

      final result = await _pb.collection('tutor_profiles').getList(
            filter: filterStr,
            sort: '-rating,+priceMin',
            perPage: 100,
            expand: 'userId',
          );

      debugPrint('[TutorProfileService] ✅ Найдено репетиторов: ${result.totalItems}');

      return result.items
          .map((record) => TutorProfile.fromRecord(record))
          .toList();
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка поиска репетиторов: $e');
      return [];
    }
  }
}
