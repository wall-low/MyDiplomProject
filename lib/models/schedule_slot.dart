import 'package:pocketbase/pocketbase.dart';

/// Модель слота расписания репетитора
///
/// Мигрировано с Firestore на PocketBase
/// Добавлен метод fromRecord() для преобразования RecordModel
class ScheduleSlot {
  final String id;
  final String tutorId;
  final DateTime date;
  final String startTime; // Формат: "09:00"
  final String endTime; // Формат: "10:00"
  final bool isBooked;
  final String? studentId; // ID ученика, если слот забронирован
  final DateTime createdAt; // ИЗМЕНЕНО: Timestamp → DateTime

  ScheduleSlot({
    required this.id,
    required this.tutorId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.studentId,
    required this.createdAt,
  });

  /// Создание ScheduleSlot из RecordModel (PocketBase)
  ///
  /// НОВЫЙ МЕТОД для работы с PocketBase
  ///
  /// RecordModel содержит:
  /// - record.id - ID слота
  /// - record.data - Map с данными слота
  /// - record.created - дата создания (ISO 8601 строка)
  /// - record.updated - дата обновления (ISO 8601 строка)
  factory ScheduleSlot.fromRecord(RecordModel record) {
    final data = record.data;

    // Парсинг date из ISO 8601 строки
    DateTime parsedDate;
    try {
      final dateStr = data['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedDate = DateTime.parse(dateStr);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      print('[ScheduleSlot] Ошибка парсинга date: $e');
      parsedDate = DateTime.now();
    }

    // Парсинг createdAt из record.created
    DateTime parsedCreatedAt;
    try {
      parsedCreatedAt = DateTime.parse(record.created);
    } catch (e) {
      print('[ScheduleSlot] Ошибка парсинга createdAt: $e');
      parsedCreatedAt = DateTime.now();
    }

    return ScheduleSlot(
      id: record.id,
      tutorId: data['tutorId'] as String? ?? '',
      date: parsedDate,
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      isBooked: data['isBooked'] as bool? ?? false,
      studentId: data['studentId'] as String?,
      createdAt: parsedCreatedAt,
    );
  }

  /// Создание ScheduleSlot из Map (для совместимости)
  ///
  /// ОБНОВЛЕНО для работы с DateTime вместо Timestamp
  factory ScheduleSlot.fromMap(Map<String, dynamic> map, String id) {
    // Парсинг date
    DateTime parsedDate;
    try {
      if (map['date'] is String) {
        // ISO 8601 строка из PocketBase
        parsedDate = DateTime.parse(map['date']);
      } else {
        // Fallback
        parsedDate = DateTime.now();
      }
    } catch (e) {
      print('[ScheduleSlot] Ошибка парсинга date в fromMap: $e');
      parsedDate = DateTime.now();
    }

    // Парсинг createdAt
    DateTime parsedCreatedAt;
    try {
      if (map['createdAt'] is String) {
        parsedCreatedAt = DateTime.parse(map['createdAt']);
      } else {
        parsedCreatedAt = DateTime.now();
      }
    } catch (e) {
      print('[ScheduleSlot] Ошибка парсинга createdAt в fromMap: $e');
      parsedCreatedAt = DateTime.now();
    }

    return ScheduleSlot(
      id: id,
      tutorId: map['tutorId'] ?? '',
      date: parsedDate,
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      isBooked: map['isBooked'] ?? false,
      studentId: map['studentId'],
      createdAt: parsedCreatedAt,
    );
  }

  /// Преобразование ScheduleSlot в Map для отправки в PocketBase
  ///
  /// ИЗМЕНЕНИЯ:
  /// - date: Timestamp.fromDate() → date.toIso8601String()
  /// - createdAt: Timestamp → DateTime.toIso8601String()
  ///
  /// PocketBase автоматически парсит ISO 8601 строки в date тип
  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,

      // ИЗМЕНЕНИЕ: Преобразование DateTime в ISO 8601 строку
      //
      // БЫЛО (Firestore):
      // 'date': Timestamp.fromDate(date)
      //
      // СТАЛО (PocketBase):
      // 'date': date.toIso8601String()
      //
      // Пример: DateTime(2024, 1, 15) → "2024-01-15T00:00:00.000"
      // PocketBase автоматически распознает и сохраняет как date тип
      'date': date.toIso8601String(),

      'startTime': startTime,
      'endTime': endTime,
      'isBooked': isBooked,
      'studentId': studentId,

      // createdAt обычно не нужен в toMap() - PocketBase создает автоматически
      // Но оставим для совместимости
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Копирование с изменениями
  ScheduleSlot copyWith({
    String? id,
    String? tutorId,
    DateTime? date,
    String? startTime,
    String? endTime,
    bool? isBooked,
    String? studentId,
    DateTime? createdAt, // ИЗМЕНЕНО: Timestamp → DateTime
  }) {
    return ScheduleSlot(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBooked: isBooked ?? this.isBooked,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Проверка, прошел ли слот
  bool get isPast {
    final now = DateTime.now();
    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(endTime.split(':')[0]),
      int.parse(endTime.split(':')[1]),
    );
    return slotDateTime.isBefore(now);
  }
}
