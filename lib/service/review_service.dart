import 'package:flutter/foundation.dart';
import '../models/review.dart';
import 'pocketbase_service.dart';
import 'tutor_profile_service.dart';

class ReviewService extends ChangeNotifier {
  final _pb = PocketBaseService().client;
  final _tutorProfileService = TutorProfileService();

  Future<Review?> createReview({
    required String tutorId,
    required String studentId,
    required String lessonId,
    int? rating,
    String? comment,
    required bool isVerified,
  }) async {
    try {
      final weight = await _countPaidLessonsBetween(studentId, tutorId);

      final existing = await _findExistingReview(studentId, lessonId);

      Review? review;
      if (existing != null) {
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

      await _recalculateTutorRating(tutorId);

      notifyListeners();
      return review;
    } catch (e) {
      debugPrint('[ReviewService] ❌ Ошибка создания отзыва: $e');
      return null;
    }
  }

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

  Future<void> refreshTutorRating(String tutorId) =>
      _recalculateTutorRating(tutorId);

  Future<bool> hasReviewForLesson(String studentId, String lessonId) async {
    final review = await _findExistingReview(studentId, lessonId);
    return review != null;
  }

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

  Future<int> _countTotalPaidLessons(String tutorId) async {
    try {
      final result = await _pb.collection('payments').getList(
        filter: 'tutorId="$tutorId" && (status="completed" || status="completed_external")',
        perPage: 1,
      );
      return result.totalItems;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countPaidLessonsBetween(
      String studentId, String tutorId) async {
    try {
      final result = await _pb.collection('payments').getList(
        filter:
            'studentId="$studentId" && tutorId="$tutorId" && (status="completed" || status="completed_external")',
        perPage: 200,
      );
      return result.totalItems;
    } catch (_) {
      return 1;
    }
  }

  Future<void> _recalculateTutorRating(String tutorId) async {
    try {
      debugPrint('[ReviewService] 🔄 Начало пересчёта рейтинга для: $tutorId');

      // 1. Получаем ВСЕ проверенные отзывы репетитора (без лимита в 180 дней)
      final reviewsResult = await _pb.collection('reviews').getFullList(
        filter: 'tutorId="$tutorId" && isVerified=true',
        sort: '-created',
      );

      final reviews = reviewsResult.map(Review.fromRecord).toList();

      if (reviews.isEmpty) {
        debugPrint('[ReviewService] ℹ️ Отзывов нет, проверяем только оплаты');
        final paidLessonsCount = await _countTotalPaidLessons(tutorId);
        final profile = await _tutorProfileService.getTutorProfileByUserId(tutorId);
        if (profile != null) {
          await _tutorProfileService.updateRating(
            profileId: profile.id,
            newRating: 0.0,
            totalPaidLessons: paidLessonsCount,
            isNewbie: paidLessonsCount == 0,
          );
        }
        return;
      }

      // 2. Получаем ВСЕ оплаты этого репетитора, чтобы посчитать веса учеников за один раз
      final paymentsResult = await _pb.collection('payments').getFullList(
        filter: 'tutorId="$tutorId" && (status="completed" || status="completed_external")',
      );
      
      // Группируем оплаты по ученикам для быстрого доступа
      final Map<String, int> studentPaymentsCount = {};
      for (final p in paymentsResult) {
        final sId = p.data['studentId'] as String? ?? '';
        if (sId.isNotEmpty) {
          studentPaymentsCount[sId] = (studentPaymentsCount[sId] ?? 0) + 1;
        }
      }

      // 3. Группируем оценки по ученикам
      final Map<String, List<int>> studentRatings = {};
      for (final r in reviews) {
        if (r.rating != null) {
          studentRatings.putIfAbsent(r.studentId, () => []);
          studentRatings[r.studentId]!.add(r.rating!);
        }
      }

      // 4. Считаем средневзвешенный рейтинг
      double weightedSum = 0;
      double weightSum = 0;
      
      for (final entry in studentRatings.entries) {
        final studentId = entry.key;
        final ratings = entry.value;
        
        final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
        
        // Вес зависит от количества оплаченных занятий (от 1 до 20)
        final paidLessons = studentPaymentsCount[studentId] ?? 1;
        final weight = paidLessons.clamp(1, 20).toDouble();
        
        weightedSum += avgRating * weight;
        weightSum += weight;
      }

      final newRating = weightSum > 0 ? weightedSum / weightSum : 0.0;
      final totalPaidLessons = paymentsResult.length;

      // 5. Обновляем профиль
      final profile = await _tutorProfileService.getTutorProfileByUserId(tutorId);
      if (profile != null) {
        await _tutorProfileService.updateRating(
          profileId: profile.id,
          newRating: double.parse(newRating.toStringAsFixed(1)),
          totalPaidLessons: totalPaidLessons,
          isNewbie: false, // Раз есть отзывы/оплаты, уже не новичок
        );
      }

      debugPrint(
          '[ReviewService] ✅ Рейтинг пересчитан: $newRating, Оплат всего: $totalPaidLessons');
    } catch (e, stack) {
      debugPrint('[ReviewService] ❌ Ошибка пересчёта рейтинга: $e');
      debugPrint(stack.toString());
    }
  }
}
