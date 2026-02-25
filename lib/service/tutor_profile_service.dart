import 'package:flutter/foundation.dart';
import '../models/tutor_profile.dart';
import 'pocketbase_service.dart';

/// Сервис для работы с расширенными профилями репетиторов
///
/// Работает с коллекцией tutor_profiles в PocketBase
/// Управляет данными: предметы, цены, опыт, рейтинг
class TutorProfileService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  /// Создать профиль репетитора
  ///
  /// ВАЖНО: userId должен быть уникальным (Relation field с unique constraint)
  /// Если профиль уже существует, вернёт ошибку
  ///
  /// Параметры:
  /// - userId: ID пользователя из users коллекции
  /// - subjects: список предметов ["Математика", "Физика"]
  /// - priceMin/priceMax: диапазон цен
  /// - experience: опыт в годах
  /// - education: образование
  /// - lessonFormat: ["online", "offline"]
  ///
  /// Возвращает: созданный TutorProfile или null при ошибке
  Future<TutorProfile?> createTutorProfile({
    required String userId,
    List<String> subjects = const [],
    double? priceMin,
    double? priceMax,
    int? experience,
    String? education,
    List<String> lessonFormat = const [],
  }) async {
    try {
      // Проверяем, не существует ли уже профиль
      final exists = await checkIfTutorProfileExists(userId);
      if (exists) {
        debugPrint('[TutorProfileService] ❌ Профиль для userId=$userId уже существует');
        return null;
      }

      // Подготавливаем данные для создания
      final body = {
        'userId': userId,
        'subjects': subjects,
        if (priceMin != null) 'priceMin': priceMin,
        if (priceMax != null) 'priceMax': priceMax,
        if (experience != null) 'experience': experience,
        if (education != null && education.isNotEmpty) 'education': education,
        'lessonFormat': lessonFormat,
        // Default значения (устанавливаем явно, т.к. PocketBase может не иметь default)
        'rating': 0.0,
        'totalPaidLessons': 0,
        'isNewbie': true,
      };

      debugPrint('[TutorProfileService] 📝 Создание профиля: $body');

      // Создаём запись в PocketBase
      final record = await _pb.collection('tutor_profiles').create(body: body);

      debugPrint('[TutorProfileService] ✅ Профиль создан: ${record.id}');

      // Уведомляем слушателей об изменении
      notifyListeners();

      return TutorProfile.fromRecord(record);
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка создания профиля: $e');
      return null;
    }
  }

  /// Получить профиль репетитора по userId
  ///
  /// userId - это ID пользователя в коллекции users (не ID записи в tutor_profiles!)
  ///
  /// Возвращает: TutorProfile или null, если не найден
  Future<TutorProfile?> getTutorProfileByUserId(String userId) async {
    try {
      // Запрос: ищем запись, где userId = переданный ID
      //
      // PocketBase filter syntax:
      // userId="abc123" - поиск по Relation field
      final result = await _pb.collection('tutor_profiles').getList(
            filter: 'userId="$userId"',
            perPage: 1, // Ожидаем только 1 запись (userId уникален)
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

  /// Получить профиль репетитора по ID записи
  ///
  /// profileId - это ID записи в коллекции tutor_profiles
  ///
  /// Возвращает: TutorProfile или null, если не найден
  Future<TutorProfile?> getTutorProfileById(String profileId) async {
    try {
      final record = await _pb.collection('tutor_profiles').getOne(profileId);
      return TutorProfile.fromRecord(record);
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка получения профиля по ID: $e');
      return null;
    }
  }

  /// Обновить профиль репетитора
  ///
  /// profileId - ID записи в tutor_profiles (НЕ userId!)
  ///
  /// Можно обновить любые поля:
  /// - subjects, priceMin, priceMax, experience, education, lessonFormat
  /// - rating, totalPaidLessons (обновляются системой при оплате)
  /// - isNewbie (можно скрыть бейдж вручную)
  ///
  /// Возвращает: обновлённый TutorProfile или null при ошибке
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

      // Уведомляем слушателей
      notifyListeners();

      return TutorProfile.fromRecord(record);
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка обновления профиля: $e');
      return null;
    }
  }

  /// Удалить профиль репетитора
  ///
  /// profileId - ID записи в tutor_profiles
  ///
  /// Используется, если репетитор переключается обратно на роль "Ученик"
  Future<bool> deleteTutorProfile(String profileId) async {
    try {
      await _pb.collection('tutor_profiles').delete(profileId);

      debugPrint('[TutorProfileService] ✅ Профиль удалён: $profileId');

      // Уведомляем слушателей
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка удаления профиля: $e');
      return false;
    }
  }

  /// Проверить, существует ли профиль для данного пользователя
  ///
  /// userId - ID пользователя в users коллекции
  ///
  /// Возвращает: true если профиль существует, false если нет
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

  /// Обновить рейтинг репетитора после получения нового отзыва
  ///
  /// Эта функция будет вызываться системой отзывов (reviews)
  /// Пересчитывает средний взвешенный рейтинг за последние 6 месяцев
  ///
  /// Параметры:
  /// - profileId: ID профиля в tutor_profiles
  /// - newRating: новый средний рейтинг (уже взвешенный)
  /// - totalLessons: новое количество оплаченных занятий
  ///
  /// TODO: Эта логика будет доработана при создании системы отзывов
  Future<bool> updateRating({
    required String profileId,
    required double newRating,
    required int totalLessons,
  }) async {
    try {
      await _pb.collection('tutor_profiles').update(
        profileId,
        body: {
          'rating': newRating,
          'totalPaidLessons': totalLessons,
          'isNewbie': totalLessons == 0, // Автоматически убираем бейдж
        },
      );

      debugPrint('[TutorProfileService] ✅ Рейтинг обновлён: $newRating ($totalLessons занятий)');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[TutorProfileService] ❌ Ошибка обновления рейтинга: $e');
      return false;
    }
  }

  /// Увеличить счётчик оплаченных занятий
  ///
  /// Вызывается после успешной оплаты занятия
  ///
  /// Параметры:
  /// - profileId: ID профиля в tutor_profiles
  ///
  /// TODO: Эта логика будет доработана при создании системы оплаты
  Future<bool> incrementPaidLessons(String profileId) async {
    try {
      // Сначала получаем текущий профиль
      final profile = await getTutorProfileById(profileId);
      if (profile == null) return false;

      // Увеличиваем счётчик
      final newTotal = profile.totalPaidLessons + 1;

      await _pb.collection('tutor_profiles').update(
        profileId,
        body: {
          'totalPaidLessons': newTotal,
          'lastPaidLessonDate': DateTime.now().toIso8601String(),
          'isNewbie': false, // Убираем бейдж новичка
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

  /// Получить всех репетиторов с фильтрацией
  ///
  /// Используется на странице поиска репетиторов
  ///
  /// Параметры фильтрации:
  /// - subjects: фильтр по предметам (если не пусто)
  /// - minPrice/maxPrice: диапазон цен
  /// - minRating: минимальный рейтинг
  /// - lessonFormat: формат занятий ("online" или "offline")
  ///
  /// Возвращает: список TutorProfile
  ///
  /// TODO: Эта функция будет использована при доработке поиска репетиторов
  Future<List<TutorProfile>> searchTutors({
    List<String>? subjects,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? lessonFormat,
  }) async {
    try {
      // Строим filter для PocketBase
      List<String> filters = [];

      // Фильтр по предметам (если JSON массив содержит один из предметов)
      // PocketBase: subjects ?~ 'Математика' - проверка наличия в JSON массиве
      if (subjects != null && subjects.isNotEmpty) {
        // Для каждого предмета создаём условие OR
        final subjectFilters =
            subjects.map((s) => 'subjects ?~ "$s"').toList();
        filters.add('(${subjectFilters.join(' || ')})');
      }

      // Фильтр по цене
      if (minPrice != null) {
        filters.add('priceMin >= $minPrice');
      }
      if (maxPrice != null) {
        filters.add('priceMax <= $maxPrice');
      }

      // Фильтр по рейтингу
      if (minRating != null) {
        filters.add('rating >= $minRating');
      }

      // Фильтр по формату занятий
      if (lessonFormat != null) {
        filters.add('lessonFormat ?~ "$lessonFormat"');
      }

      // Объединяем все фильтры через AND
      final filterStr = filters.isNotEmpty ? filters.join(' && ') : '';

      debugPrint('[TutorProfileService] 🔍 Поиск репетиторов: $filterStr');

      // Запрос к PocketBase с expand для загрузки данных пользователя
      final result = await _pb.collection('tutor_profiles').getList(
            filter: filterStr,
            sort: '-rating,+priceMin', // Сортировка: сначала по рейтингу, потом по цене
            perPage: 100,
            expand: 'userId', // Загружаем связанные данные пользователя
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
