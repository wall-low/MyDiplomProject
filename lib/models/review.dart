import 'package:pocketbase/pocketbase.dart';

/// Модель отзыва ученика о репетиторе
///
/// isVerified = true → отзыв оставлен после оплаченного занятия
///   - содержит рейтинг (1-5) и влияет на рейтинг репетитора
/// isVerified = false → текстовый отзыв без оплаты
///   - не влияет на рейтинг, помечается как "неверифицированный"
///
/// weight = количество оплаченных занятий между этим учеником и репетитором
///   - чем больше занятий → тем весомее отзыв
class Review {
  final String id;
  final String tutorId; // Relation → users.id (кому отзыв)
  final String studentId; // Relation → users.id (кто оставил)
  final String? lessonId; // Relation → slots.id (за какое занятие)
  final int? rating; // 1-5, null для неверифицированных
  final String? comment; // Текст отзыва (необязательно)
  final bool isVerified; // true = оплаченное занятие
  final int weight; // Вес отзыва (кол-во оплач. занятий с этим учеником)
  final DateTime created;

  Review({
    required this.id,
    required this.tutorId,
    required this.studentId,
    this.lessonId,
    this.rating,
    this.comment,
    this.isVerified = false,
    this.weight = 1,
    required this.created,
  });

  factory Review.fromRecord(RecordModel record) {
    final data = record.data;

    int? parsedRating;
    try {
      final v = data['rating'];
      if (v is int) { parsedRating = v; }
      else if (v is double) { parsedRating = v.toInt(); }
      else if (v is String) { parsedRating = int.tryParse(v); }
    } catch (_) {}

    int parsedWeight = 1;
    try {
      final v = data['weight'];
      if (v is int) { parsedWeight = v; }
      else if (v is double) { parsedWeight = v.toInt(); }
      else if (v is String) { parsedWeight = int.tryParse(v) ?? 1; }
    } catch (_) {}

    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(record.get<String>('created'));
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    return Review(
      id: record.id,
      tutorId: data['tutorId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      lessonId: data['lessonId'] as String?,
      rating: parsedRating,
      comment: data['comment'] as String?,
      isVerified: data['isVerified'] as bool? ?? false,
      weight: parsedWeight,
      created: parsedCreated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,
      'studentId': studentId,
      if (lessonId != null) 'lessonId': lessonId,
      if (rating != null) 'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      'isVerified': isVerified,
      'weight': weight,
    };
  }

  /// Попадает ли отзыв в 6-месячное окно для рейтинга
  bool get isWithinRatingWindow {
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    return created.isAfter(cutoff);
  }

  /// Дата в читаемом формате
  String getCreatedDisplay() {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${created.day} ${months[created.month - 1]} ${created.year}';
  }
}
