import 'package:pocketbase/pocketbase.dart';

class Review {
  final String id;
  final String tutorId;
  final String studentId;
  final String? lessonId;
  final int? rating;
  final String? comment;
  final bool isVerified;
  final int weight;
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

  bool get isWithinRatingWindow {
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    return created.isAfter(cutoff);
  }

  String getCreatedDisplay() {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${created.day} ${months[created.month - 1]} ${created.year}';
  }
}
