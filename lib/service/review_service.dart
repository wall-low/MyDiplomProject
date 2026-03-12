import 'package:flutter/foundation.dart';
import '../models/review.dart';
import 'pocketbase_service.dart';
import 'tutor_profile_service.dart';

/// Сервис для работы с отзывами
///
/// Логика рейтинга:
/// - Только верифицированные отзывы (isVerified=true) влияют на рейтинг
/// - Учитываются только отзывы за последние 6 месяцев
/// - Взвешенный рейтинг: sum(rating * weight) / sum(weight)
/// - weight = кол-во оплаченных занятий с этим учеником
class ReviewService extends ChangeNotifier {
  final _pb = PocketBaseService().client;
  final _tutorProfileService = TutorProfileService();

  /// Создать отзыв после занятия
  ///
  /// Если ученик уже оставлял отзыв за этот слот — обновляет существующий
  Future<Review?> createReview({
    required String tutorId,
    required String studentId,
    required String lessonId,
    int? rating,
    String? comment,
    required bool isVerified,
  }) async {
    try {
      // Считаем вес = кол-во оплаченных занятий между студентом и репетитором
      final weight = await _countPaidLessonsBetween(studentId, tutorId);

      // Проверяем, есть ли уже отзыв за этот слот от этого студента
      final existing = await _findExistingReview(studentId, lessonId);

      Review? review;
      if (existing != null) {
        // Обновляем существующий
        final record = await _pb.collection('reviews').update(
          existing.id,
          body: {
            if (rating != null) 'rating': rating,
            if (comment != null) 'comment': comment,
            'isVerified': isVerified,
            'weight': weight,
          },
        );
        review = Review.fromRecord(record);
        debugPrint('[ReviewService] ✅ Отзыв обновлён: ${record.id}');
      } else {
        // Создаём новый
        final record = await _pb.collection('reviews').create(
          body: {
            'tutorId': tutorId,
            'studentId': studentId,
            'lessonId': lessonId,
            if (rating != null) 'rating': rating,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
            'isVerified': isVerified,
            'weight': weight,
          },
        );
        review = Review.fromRecord(record);
        debugPrint('[ReviewService] ✅ Отзыв создан: ${record.id}');
      }

      // Пересчитываем рейтинг репетитора
      await _recalculateTutorRating(tutorId);

      notifyListeners();
      return review;
    } catch (e) {
      debugPrint('[ReviewService] ❌ Ошибка создания отзыва: $e');
      return null;
    }
  }

  /// Получить все отзывы для репетитора (для профиля)
  Future<List<Review>> getTutorReviews(String tutorId) async {
    try {
      final result = await _pb.collection('reviews').getList(
        filter: 'tutorId="$tutorId"',
        sort: '-created',
        perPage: 50,
      );
      return result.items.map(Review.fromRecord).toList();
    } catch (e) {
      debugPrint('[ReviewService] ❌ Ошибка получения отзывов: $e');
      return [];
    }
  }

  /// Пересчитать рейтинг репетитора — публичный метод.
  ///
  /// Вызывать при каждом просмотре профиля репетитора.
  /// Так рейтинг автоматически снижается, когда отзывы выходят за 6-месячное окно.
  /// Репетиторы вынуждены постоянно получать новые оплаченные занятия
  /// через приложение чтобы поддерживать высокий рейтинг.
  Future<void> refreshTutorRating(String tutorId) =>
      _recalculateTutorRating(tutorId);

  /// Проверить, оставил ли студент отзыв за этот слот
  Future<bool> hasReviewForLesson(String studentId, String lessonId) async {
    final review = await _findExistingReview(studentId, lessonId);
    return review != null;
  }

  /// Найти существующий отзыв студента за конкретный слот
  Future<Review?> _findExistingReview(
      String studentId, String lessonId) async {
    try {
      final result = await _pb.collection('reviews').getList(
        filter: 'studentId="$studentId" && lessonId="$lessonId"',
        perPage: 1,
      );
      if (result.items.isEmpty) return null;
      return Review.fromRecord(result.items.first);
    } catch (_) {
      return null;
    }
  }

  /// Посчитать кол-во оплаченных занятий между студентом и репетитором
  Future<int> _countPaidLessonsBetween(
      String studentId, String tutorId) async {
    try {
      final result = await _pb.collection('payments').getList(
        filter:
            'studentId="$studentId" && tutorId="$tutorId" && status="completed"',
        perPage: 200,
      );
      return result.totalItems;
    } catch (_) {
      return 1;
    }
  }

  /// Пересчитать взвешенный рейтинг репетитора за последние 6 месяцев.
  ///
  /// totalPaidLessons = сумма весов верифицированных отзывов в окне 6 мес.
  /// (proxy для "активных оплаченных занятий" — не зависит от прав на payments)
  ///
  /// isNewbie = true только если в 6-мес. окне нет ни одного верифицированного отзыва
  Future<void> _recalculateTutorRating(String tutorId) async {
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 180))
          .toIso8601String();

      final result = await _pb.collection('reviews').getList(
        filter: 'tutorId="$tutorId" && isVerified=true && created>="$cutoff"',
        perPage: 500,
      );

      final reviews = result.items.map(Review.fromRecord).toList();

      double weightSum = 0;
      double weightedSum = 0;
      for (final r in reviews) {
        if (r.rating != null) {
          weightedSum += r.rating! * r.weight;
          weightSum += r.weight;
        }
      }

      // Взвешенный рейтинг за 6 мес.
      final newRating = weightSum > 0 ? weightedSum / weightSum : 0.0;

      // totalPaidLessons = сумма весов = кол-во активных оплаченных занятий в окне
      // isNewbie = нет ни одного верифицированного отзыва в 6-мес. окне
      final activeLessons = weightSum.toInt();
      final isNewbie = activeLessons == 0;

      final profile = await _tutorProfileService.getTutorProfileByUserId(tutorId);
      if (profile != null) {
        await _tutorProfileService.updateRating(
          profileId: profile.id,
          newRating: double.parse(newRating.toStringAsFixed(1)),
          totalPaidLessons: activeLessons,
          isNewbie: isNewbie,
        );
      }

      debugPrint(
          '[ReviewService] ✅ Рейтинг: $newRating, активных занятий: $activeLessons');
    } catch (e) {
      debugPrint('[ReviewService] ❌ Ошибка пересчёта рейтинга: $e');
    }
  }
}
