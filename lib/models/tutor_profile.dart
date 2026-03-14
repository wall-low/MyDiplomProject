import 'package:pocketbase/pocketbase.dart';

class TutorProfile {
  final String id;
  final String userId;
  final List<String> subjects;
  final double? priceMin;
  final double? priceMax;
  final int? experience;
  final String? education;
  final List<String> lessonFormat;
  final double rating;
  final int totalPaidLessons;
  final DateTime? lastPaidLessonDate;
  final bool isNewbie;
  final String? payoutCardLast4;

  TutorProfile({
    required this.id,
    required this.userId,
    this.subjects = const [],
    this.priceMin,
    this.priceMax,
    this.experience,
    this.education,
    this.lessonFormat = const [],
    this.rating = 0.0,
    this.totalPaidLessons = 0,
    this.lastPaidLessonDate,
    this.isNewbie = true,
    this.payoutCardLast4,
  });

  factory TutorProfile.fromRecord(RecordModel record) {
    final data = record.data;

    List<String> parsedSubjects = [];
    try {
      final subjectsData = data['subjects'];
      if (subjectsData is List) {
        parsedSubjects = subjectsData.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('[TutorProfile] Ошибка парсинга subjects: $e');
    }

    List<String> parsedLessonFormat = [];
    try {
      final formatData = data['lessonFormat'];
      if (formatData is List) {
        parsedLessonFormat = formatData.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('[TutorProfile] Ошибка парсинга lessonFormat: $e');
    }

    DateTime? parsedLastPaidDate;
    try {
      final dateStr = data['lastPaidLessonDate'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedLastPaidDate = DateTime.parse(dateStr);
      }
    } catch (e) {
      print('[TutorProfile] Ошибка парсинга lastPaidLessonDate: $e');
    }

    double? parseDouble(String key) {
      try {
        final value = data[key];
        if (value == null) return null;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      } catch (e) {
        print('[TutorProfile] Ошибка парсинга $key: $e');
        return null;
      }
    }

    int? parseInt(String key) {
      try {
        final value = data[key];
        if (value == null) return null;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      } catch (e) {
        print('[TutorProfile] Ошибка парсинга $key: $e');
        return null;
      }
    }

    return TutorProfile(
      id: record.id,
      userId: data['userId'] as String? ?? '',
      subjects: parsedSubjects,
      priceMin: parseDouble('priceMin'),
      priceMax: parseDouble('priceMax'),
      experience: parseInt('experience'),
      education: data['education'] as String?,
      lessonFormat: parsedLessonFormat,
      rating: parseDouble('rating') ?? 0.0,
      totalPaidLessons: parseInt('totalPaidLessons') ?? 0,
      lastPaidLessonDate: parsedLastPaidDate,
      isNewbie: data['isNewbie'] as bool? ?? true,
      payoutCardLast4: data['payoutCardLast4'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subjects': subjects,
      if (priceMin != null) 'priceMin': priceMin,
      if (priceMax != null) 'priceMax': priceMax,
      if (experience != null) 'experience': experience,
      if (education != null) 'education': education,
      'lessonFormat': lessonFormat,
      'rating': rating,
      'totalPaidLessons': totalPaidLessons,
      if (lastPaidLessonDate != null)
        'lastPaidLessonDate': lastPaidLessonDate!.toIso8601String(),
      'isNewbie': isNewbie,
      if (payoutCardLast4 != null) 'payoutCardLast4': payoutCardLast4,
    };
  }

  TutorProfile copyWith({
    String? id,
    String? userId,
    List<String>? subjects,
    double? priceMin,
    double? priceMax,
    int? experience,
    String? education,
    List<String>? lessonFormat,
    double? rating,
    int? totalPaidLessons,
    DateTime? lastPaidLessonDate,
    bool? isNewbie,
    String? payoutCardLast4,
  }) {
    return TutorProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subjects: subjects ?? this.subjects,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      lessonFormat: lessonFormat ?? this.lessonFormat,
      rating: rating ?? this.rating,
      totalPaidLessons: totalPaidLessons ?? this.totalPaidLessons,
      lastPaidLessonDate: lastPaidLessonDate ?? this.lastPaidLessonDate,
      isNewbie: isNewbie ?? this.isNewbie,
      payoutCardLast4: payoutCardLast4 ?? this.payoutCardLast4,
    );
  }

  String getPriceDisplay() {
    if (priceMin != null && priceMax != null) {
      return '${priceMin!.toInt()}-${priceMax!.toInt()} ₽/час';
    } else if (priceMin != null) {
      return 'от ${priceMin!.toInt()} ₽/час';
    } else if (priceMax != null) {
      return 'до ${priceMax!.toInt()} ₽/час';
    } else {
      return 'Цена не указана';
    }
  }

  String getExperienceDisplay() {
    if (experience == null) return 'Опыт не указан';

    if (experience == 1) {
      return '$experience год';
    } else if (experience! >= 2 && experience! <= 4) {
      return '$experience года';
    } else {
      return '$experience лет';
    }
  }

  String getLessonFormatDisplay() {
    if (lessonFormat.isEmpty) return 'Не указано';

    final formats = lessonFormat.map((f) {
      if (f == 'online') return 'Онлайн';
      if (f == 'offline') return 'Оффлайн';
      return f;
    }).toList();

    return formats.join(' и ');
  }

  bool get isReallyNewbie => totalPaidLessons == 0 || isNewbie;

  String getRatingDisplay() {
    if (isReallyNewbie) {
      return '🆕 Новичок на платформе';
    }

    final lessonsWord = _getPluralLessons(totalPaidLessons);
    return 'Рейтинг ${rating.toStringAsFixed(1)} ⭐ ($totalPaidLessons $lessonsWord)';
  }

  String _getPluralLessons(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'оплаченное занятие';
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'оплаченных занятия';
    } else {
      return 'оплаченных занятий';
    }
  }
}
