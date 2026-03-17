import 'package:pocketbase/pocketbase.dart';


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

  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
    };
  }

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

  String getDayShortName() {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    if (dayOfWeek < 1 || dayOfWeek > 7) return '?';
    return days[dayOfWeek - 1];
  }

  String getDayEmoji() {
    return '📅';
  }

  String getTimeDisplay() {
    return '$startTime - $endTime';
  }

  String getFullDisplay() {
    return '${getDayName()}: $startTime - $endTime';
  }

  bool isWeekday() {
    return dayOfWeek >= 1 && dayOfWeek <= 5;
  }

  bool isWeekend() {
    return dayOfWeek == 6 || dayOfWeek == 7;
  }
}
