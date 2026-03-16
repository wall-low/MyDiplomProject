import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// Модель платежа (имитация оплаты для диплома)
///
/// Связан с:
/// - users (studentId, tutorId) - кто платит и кому
/// - slots (slotId) - за какое занятие
///
/// Статусы:
/// - pending: ожидает оплаты
/// - completed: успешно оплачено
/// - failed: ошибка оплаты
class Payment {
  final String id; // ID записи в payments
  final String studentId; // Relation → users.id (кто платит)
  final String tutorId; // Relation → users.id (кому платят)
  final String slotId; // Relation → slots.id (за какое занятие)
  final double amount; // Сумма оплаты в рублях
  final String status; // "pending" | "completed" | "failed"
  final DateTime created; // Дата создания платежа

  Payment({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.slotId,
    required this.amount,
    this.status = 'pending',
    required this.created,
  });

  /// Создание Payment из RecordModel (PocketBase)
  ///
  /// RecordModel возвращается PocketBase при запросах к коллекции payments:
  /// - record.id - ID записи в payments
  /// - record.data - Map<String, dynamic> с данными платежа
  /// - record.created - ISO 8601 строка с датой создания
  ///
  /// Поля из record.data:
  /// - studentId: ID ученика (Relation → users.id)
  /// - tutorId: ID репетитора (Relation → users.id)
  /// - slotId: ID слота (Relation → slots.id)
  /// - amount: число (сумма в рублях)
  /// - status: строка ("pending", "completed", "failed")
  factory Payment.fromRecord(RecordModel record) {
    final data = record.data;

    // Парсинг amount с fallback
    double parsedAmount = 0.0;
    try {
      final amountValue = data['amount'];
      if (amountValue is double) {
        parsedAmount = amountValue;
      } else if (amountValue is int) {
        parsedAmount = amountValue.toDouble();
      } else if (amountValue is String) {
        parsedAmount = double.tryParse(amountValue) ?? 0.0;
      }
    } catch (e) {
      debugPrint('[Payment] Ошибка парсинга amount: $e');
    }

    // Парсинг created из record.created
    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(record.created);
    } catch (e) {
      debugPrint('[Payment] Ошибка парсинга created: $e');
      parsedCreated = DateTime.now();
    }

    return Payment(
      id: record.id,
      studentId: data['studentId'] as String? ?? '',
      tutorId: data['tutorId'] as String? ?? '',
      slotId: data['slotId'] as String? ?? '',
      amount: parsedAmount,
      status: data['status'] as String? ?? 'pending',
      created: parsedCreated,
    );
  }

  /// Преобразование Payment в Map для отправки в PocketBase
  ///
  /// Используется при создании платежа:
  /// pb.collection('payments').create(body: payment.toMap())
  ///
  /// ВАЖНО:
  /// - id не включается (auto-generated)
  /// - created не включается (AutodateField)
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'tutorId': tutorId,
      'slotId': slotId,
      'amount': amount,
      'status': status,
    };
  }

  /// Копирование с изменениями (иммутабельный update)
  Payment copyWith({
    String? id,
    String? studentId,
    String? tutorId,
    String? slotId,
    double? amount,
    String? status,
    DateTime? created,
  }) {
    return Payment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      tutorId: tutorId ?? this.tutorId,
      slotId: slotId ?? this.slotId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      created: created ?? this.created,
    );
  }

  /// Проверка, завершён ли платёж
  bool get isCompleted => status == 'completed';

  /// Проверка, ожидает ли платёж обработки
  bool get isPending => status == 'pending';

  /// Проверка, провалился ли платёж
  bool get isFailed => status == 'failed';

  /// Форматированная строка суммы для отображения в UI
  ///
  /// Пример: 1500.0 → "1 500 ₽"
  String getAmountDisplay() {
    final intAmount = amount.toInt();
    final formatter = intAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    return '$formatter ₽';
  }

  /// Форматированная дата для отображения
  ///
  /// Пример: "15 марта 2024, 14:30"
  String getCreatedDisplay() {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря'
    ];

    final day = created.day;
    final month = months[created.month - 1];
    final year = created.year;
    final hour = created.hour.toString().padLeft(2, '0');
    final minute = created.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute';
  }

  /// Текстовое описание статуса для UI
  String getStatusDisplay() {
    switch (status) {
      case 'pending':
        return 'Ожидает оплаты';
      case 'completed':
        return 'Оплачено';
      case 'failed':
        return 'Ошибка оплаты';
      default:
        return 'Неизвестный статус';
    }
  }

  @override
  String toString() {
    return 'Payment(id: $id, studentId: $studentId, tutorId: $tutorId, slotId: $slotId, amount: $amount, status: $status, created: $created)';
  }
}
