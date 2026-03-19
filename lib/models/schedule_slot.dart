import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

class ScheduleSlot {
  final String id;
  final String tutorId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final bool isBooked;
  final bool isPaid;
  final String? studentId;
  final DateTime createdAt;
  final bool generatedFromTemplate;
  final String? templateId;
  final String bookingStatus;
  final bool isRecurring;
  final String? recurringGroupId;
  final String? subject;

  ScheduleSlot({
    required this.id,
    required this.tutorId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.isPaid = false,
    this.studentId,
    required this.createdAt,
    this.generatedFromTemplate = false,
    this.templateId,
    this.bookingStatus = 'free',
    this.isRecurring = false,
    this.recurringGroupId,
    this.subject,
  });

  factory ScheduleSlot.fromRecord(RecordModel record) {
    final data = record.data;

    DateTime parsedDate;
    try {
      final dateStr = data['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedDate = DateTime.parse(dateStr);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      debugPrint('[ScheduleSlot] Ошибка парсинга date: $e');
      parsedDate = DateTime.now();
    }

    DateTime parsedCreatedAt;
    try {
      parsedCreatedAt = DateTime.parse(record.created);
    } catch (e) {
      debugPrint('[ScheduleSlot] Ошибка парсинга createdAt: $e');
      parsedCreatedAt = DateTime.now();
    }

    return ScheduleSlot(
      id: record.id,
      tutorId: data['tutorId'] as String? ?? '',
      date: parsedDate,
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      isBooked: data['isBooked'] as bool? ?? false,
      isPaid: data['isPaid'] as bool? ?? false,
      studentId: data['studentId'] as String?,
      createdAt: parsedCreatedAt,
      generatedFromTemplate: data['generatedFromTemplate'] as bool? ?? false,
      templateId: data['templateId'] as String?,
      bookingStatus: data['bookingStatus'] as String? ?? 'free',
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurringGroupId: data['recurringGroupId'] as String?,
      subject: data['subject'] as String?,
    );
  }

  factory ScheduleSlot.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate;
    try {
      if (map['date'] is String) {
        parsedDate = DateTime.parse(map['date']);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      debugPrint('[ScheduleSlot] Ошибка парсинга date в fromMap: $e');
      parsedDate = DateTime.now();
    }

    DateTime parsedCreatedAt;
    try {
      if (map['createdAt'] is String) {
        parsedCreatedAt = DateTime.parse(map['createdAt']);
      } else {
        parsedCreatedAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('[ScheduleSlot] Ошибка парсинга createdAt в fromMap: $e');
      parsedCreatedAt = DateTime.now();
    }

    return ScheduleSlot(
      id: id,
      tutorId: map['tutorId'] ?? '',
      date: parsedDate,
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      isBooked: map['isBooked'] ?? false,
      isPaid: map['isPaid'] ?? false,
      studentId: map['studentId'],
      createdAt: parsedCreatedAt,
      generatedFromTemplate: map['generatedFromTemplate'] ?? false,
      templateId: map['templateId'],
      bookingStatus: map['bookingStatus'] ?? 'free',
      isRecurring: map['isRecurring'] ?? false,
      recurringGroupId: map['recurringGroupId'],
      subject: map['subject'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,

      'date': date.toIso8601String(),

      'startTime': startTime,
      'endTime': endTime,
      'isBooked': isBooked,
      'isPaid': isPaid,
      if (studentId != null) 'studentId': studentId,

      'generatedFromTemplate': generatedFromTemplate,
      if (templateId != null) 'templateId': templateId,

      'bookingStatus': bookingStatus,

      'isRecurring': isRecurring,
      if (recurringGroupId != null) 'recurringGroupId': recurringGroupId,
      if (subject != null) 'subject': subject,

      'createdAt': createdAt.toIso8601String(),
    };
  }

  ScheduleSlot copyWith({
    String? id,
    String? tutorId,
    DateTime? date,
    String? startTime,
    String? endTime,
    bool? isBooked,
    bool? isPaid,
    String? studentId,
    DateTime? createdAt,
    bool? generatedFromTemplate,
    String? templateId,
    String? bookingStatus,
    bool? isRecurring,
    String? recurringGroupId,
    String? subject,
  }) {
    return ScheduleSlot(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBooked: isBooked ?? this.isBooked,
      isPaid: isPaid ?? this.isPaid,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt ?? this.createdAt,
      generatedFromTemplate: generatedFromTemplate ?? this.generatedFromTemplate,
      templateId: templateId ?? this.templateId,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
      subject: subject ?? this.subject,
    );
  }

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

  bool get isFree => bookingStatus == 'free';
  bool get isPending => bookingStatus == 'pending';
  bool get isConfirmed => bookingStatus == 'confirmed';

  String get statusEmoji {
    switch (bookingStatus) {
      case 'free':
        return '🟢';
      case 'pending':
        return '⏳';
      case 'confirmed':
        return '✅';
      default:
        return '❓';
    }
  }

  String get statusText {
    switch (bookingStatus) {
      case 'free':
        return 'Свободно';
      case 'pending':
        return 'Ожидает подтверждения';
      case 'confirmed':
        return 'Подтверждено';
      default:
        return 'Неизвестно';
    }
  }
}
