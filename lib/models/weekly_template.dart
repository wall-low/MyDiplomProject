import 'package:pocketbase/pocketbase.dart';

/// Модель недельного шаблона расписания репетитора
///
/// Хранит информацию о том, в какие дни недели и время репетитор обычно работает.
/// Используется для автоматической генерации конкретных слотов (slots) на несколько недель вперед.
///
/// Пример: "Каждый понедельник с 10:00 до 12:00"
class WeeklyTemplate {
  final String id; // ID записи в weekly_templates
  final String tutorId; // Relation → users.id
  final int dayOfWeek; // 1=Понедельник, 2=Вторник, ..., 7=Воскресенье
  final String startTime; // Время начала в формате HH:mm (например, "10:00")
  final String endTime; // Время окончания в формате HH:mm (например, "12:00")
  final bool isActive; // Активен ли этот слот шаблона

  WeeklyTemplate({
    required this.id,
    required this.tutorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  /// Создание WeeklyTemplate из RecordModel (PocketBase)
  factory WeeklyTemplate.fromRecord(RecordModel record) {
    final data = record.data;

    return WeeklyTemplate(
      id: record.id,
      tutorId: data['tutorId'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as int? ?? 1,
      startTime: data['startTime'] as String? ?? '00:00',
      endTime: data['endTime'] as String? ?? '00:00',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  /// Преобразование WeeklyTemplate в Map для отправки в PocketBase
  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
    };
  }

  /// Копирование с изменениями
  WeeklyTemplate copyWith({
    String? id,
    String? tutorId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isActive,
  }) {
    return WeeklyTemplate(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Получить название дня недели по-русски
  ///
  /// Примеры:
  /// - dayOfWeek: 1 → "Понедельник"
  /// - dayOfWeek: 7 → "Воскресенье"
  String getDayName() {
    const days = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье'
    ];
    if (dayOfWeek < 1 || dayOfWeek > 7) return 'Неизвестно';
    return days[dayOfWeek - 1];
  }

  /// Получить короткое название дня недели
  ///
  /// Примеры:
  /// - dayOfWeek: 1 → "Пн"
  /// - dayOfWeek: 7 → "Вс"
  String getDayShortName() {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    if (dayOfWeek < 1 || dayOfWeek > 7) return '?';
    return days[dayOfWeek - 1];
  }

  /// Получить emoji для дня недели
  String getDayEmoji() {
    return '📅';
  }

  /// Форматированная строка времени для отображения
  ///
  /// Пример: "10:00 - 12:00"
  String getTimeDisplay() {
    return '$startTime - $endTime';
  }

  /// Форматированная строка для отображения полной информации
  ///
  /// Пример: "Понедельник: 10:00 - 12:00"
  String getFullDisplay() {
    return '${getDayName()}: $startTime - $endTime';
  }

  /// Проверка, является ли день будним
  bool isWeekday() {
    return dayOfWeek >= 1 && dayOfWeek <= 5;
  }

  /// Проверка, является ли день выходным
  bool isWeekend() {
    return dayOfWeek == 6 || dayOfWeek == 7;
  }
}
