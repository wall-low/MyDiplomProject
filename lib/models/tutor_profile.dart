import 'package:pocketbase/pocketbase.dart';

/// Модель расширенного профиля репетитора
///
/// Связан с users через userId (Relation field)
/// Содержит дополнительные данные: предметы, цены, опыт, рейтинг
class TutorProfile {
  final String id; // ID записи в tutor_profiles
  final String userId; // Relation → users.id
  final List<String> subjects; // Предметы преподавания
  final double? priceMin; // Минимальная цена за час
  final double? priceMax; // Максимальная цена за час
  final int? experience; // Опыт работы в годах
  final String? education; // Образование (вуз, специальность)
  final List<String> lessonFormat; // Формат занятий: ["online", "offline"]
  final double rating; // Средний взвешенный рейтинг (0-5)
  final int totalPaidLessons; // Всего оплаченных занятий
  final DateTime? lastPaidLessonDate; // Дата последнего оплаченного занятия
  final bool isNewbie; // Показывать бейдж "🆕 Новичок"
  final String? payoutCardLast4; // Последние 4 цифры карты для получения выплат

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

  /// Создание TutorProfile из RecordModel (PocketBase)
  ///
  /// RecordModel возвращается PocketBase при запросах к коллекции tutor_profiles:
  /// - record.id - ID записи в tutor_profiles
  /// - record.data - Map<String, dynamic> с данными профиля
  ///
  /// Поля из record.data:
  /// - userId: ID связанного пользователя (Relation → users.id)
  /// - subjects: JSON массив предметов ["Математика", "Физика"]
  /// - priceMin/priceMax: числа (цена за час)
  /// - experience: число (лет опыта)
  /// - education: строка (образование)
  /// - lessonFormat: JSON массив ["online", "offline"]
  /// - rating: число (0-5)
  /// - totalPaidLessons: число (счётчик)
  /// - lastPaidLessonDate: дата ISO 8601 или null
  /// - isNewbie: bool
  factory TutorProfile.fromRecord(RecordModel record) {
    final data = record.data;

    // Парсинг subjects из JSON массива
    List<String> parsedSubjects = [];
    try {
      final subjectsData = data['subjects'];
      if (subjectsData is List) {
        parsedSubjects = subjectsData.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('[TutorProfile] Ошибка парсинга subjects: $e');
    }

    // Парсинг lessonFormat из JSON массива или Select multi
    List<String> parsedLessonFormat = [];
    try {
      final formatData = data['lessonFormat'];
      if (formatData is List) {
        parsedLessonFormat = formatData.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('[TutorProfile] Ошибка парсинга lessonFormat: $e');
    }

    // Парсинг lastPaidLessonDate
    DateTime? parsedLastPaidDate;
    try {
      final dateStr = data['lastPaidLessonDate'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedLastPaidDate = DateTime.parse(dateStr);
      }
    } catch (e) {
      print('[TutorProfile] Ошибка парсинга lastPaidLessonDate: $e');
    }

    // Парсинг числовых полей с fallback
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

  /// Преобразование TutorProfile в Map для отправки в PocketBase
  ///
  /// Используется при создании/обновлении профиля:
  /// pb.collection('tutor_profiles').create(body: tutorProfile.toMap())
  /// pb.collection('tutor_profiles').update(id, body: tutorProfile.toMap())
  ///
  /// ВАЖНО:
  /// - id не включается (передается отдельным параметром в update)
  /// - JSON массивы отправляются как List
  /// - DateTime преобразуется в ISO 8601 строку
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subjects': subjects, // PocketBase автоматически сохранит как JSON
      if (priceMin != null) 'priceMin': priceMin,
      if (priceMax != null) 'priceMax': priceMax,
      if (experience != null) 'experience': experience,
      if (education != null) 'education': education,
      'lessonFormat': lessonFormat, // PocketBase автоматически сохранит как JSON/Select
      'rating': rating,
      'totalPaidLessons': totalPaidLessons,
      if (lastPaidLessonDate != null)
        'lastPaidLessonDate': lastPaidLessonDate!.toIso8601String(),
      'isNewbie': isNewbie,
      if (payoutCardLast4 != null) 'payoutCardLast4': payoutCardLast4,
    };
  }

  /// Копирование с изменениями (иммутабельный update)
  ///
  /// Используется для обновления отдельных полей без мутации объекта
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

  /// Форматированная строка цены для отображения в UI
  ///
  /// Примеры:
  /// - priceMin: 500, priceMax: 1000 → "500-1000 ₽/час"
  /// - priceMin: 500, priceMax: null → "от 500 ₽/час"
  /// - priceMin: null, priceMax: 1000 → "до 1000 ₽/час"
  /// - priceMin: null, priceMax: null → "Цена не указана"
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

  /// Форматированная строка опыта
  ///
  /// Примеры:
  /// - experience: 1 → "1 год"
  /// - experience: 3 → "3 года"
  /// - experience: 10 → "10 лет"
  /// - experience: null → "Опыт не указан"
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

  /// Форматированная строка формата занятий
  ///
  /// Примеры:
  /// - ["online"] → "Онлайн"
  /// - ["offline"] → "Оффлайн"
  /// - ["online", "offline"] → "Онлайн и Оффлайн"
  /// - [] → "Не указано"
  String getLessonFormatDisplay() {
    if (lessonFormat.isEmpty) return 'Не указано';

    final formats = lessonFormat.map((f) {
      if (f == 'online') return 'Онлайн';
      if (f == 'offline') return 'Оффлайн';
      return f;
    }).toList();

    return formats.join(' и ');
  }

  /// Проверка, является ли репетитор новичком
  ///
  /// Новичок = 0 оплаченных занятий ИЛИ isNewbie = true
  bool get isReallyNewbie => totalPaidLessons == 0 || isNewbie;

  /// Форматированная строка рейтинга для отображения
  ///
  /// Примеры:
  /// - rating: 4.9, totalPaidLessons: 24 → "Рейтинг 4.9 ⭐ (24 оплаченных занятия)"
  /// - rating: 0, totalPaidLessons: 0 → "🆕 Новичок на платформе"
  String getRatingDisplay() {
    if (isReallyNewbie) {
      return '🆕 Новичок на платформе';
    }

    final lessonsWord = _getPluralLessons(totalPaidLessons);
    return 'Рейтинг ${rating.toStringAsFixed(1)} ⭐ ($totalPaidLessons $lessonsWord)';
  }

  /// Склонение слова "занятие"
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
