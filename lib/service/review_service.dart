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
        filter: 'tutorId="$tutorId" && status="completed"',
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
            'studentId="$studentId" && tutorId="$tutorId" && status="completed"',
        perPage: 200,
      );
      return result.totalItems;
    } catch (_) {
      return 1;
    }
  }

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

      final Map<String, List<int>> studentRatings = {};
      for (final r in reviews) {
        if (r.rating != null) {
          studentRatings.putIfAbsent(r.studentId, () => []);
          studentRatings[r.studentId]!.add(r.rating!);
        }
      }

      double weightedSum = 0;
      double weightSum = 0;
      for (final entry in studentRatings.entries) {
        final avgRating = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final paidLessons = await _countPaidLessonsBetween(entry.key, tutorId);
        final weight = paidLessons.clamp(1, 5);
        weightedSum += avgRating * weight;
        weightSum += weight;
      }

      final newRating = weightSum > 0 ? weightedSum / weightSum : 0.0;

      final paidLessonsCount = await _countTotalPaidLessons(tutorId);
      final isNewbie = studentRatings.isEmpty;

      final profile = await _tutorProfileService.getTutorProfileByUserId(tutorId);
      if (profile != null) {
        await _tutorProfileService.updateRating(
          profileId: profile.id,
          newRating: double.parse(newRating.toStringAsFixed(1)),
          totalPaidLessons: paidLessonsCount,
          isNewbie: isNewbie,
        );
      }

      debugPrint(
          '[ReviewService] ✅ Рейтинг: $newRating (${studentRatings.length} учеников), оплаченных занятий: $paidLessonsCount');
    } catch (e) {
      debugPrint('[ReviewService] ❌ Ошибка пересчёта рейтинга: $e');
    }
  }
}
