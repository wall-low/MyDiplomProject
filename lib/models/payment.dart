import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

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

  factory Payment.fromRecord(RecordModel record) {
    final data = record.data;

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

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'tutorId': tutorId,
      'slotId': slotId,
      'amount': amount,
      'status': status,
    };
  }

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


  bool get isCompleted => status == 'completed' || status == 'completed_external';

  /// Платёж добавлен репетитором вручную (не через приложение)
  bool get isManual => slotId == 'manual';

  /// Платёж произведён вне приложения (наличные / перевод)
  bool get isExternal => status == 'completed_external';

  bool get isPending => status == 'pending';


  bool get isFailed => status == 'failed';

  String getAmountDisplay() {
    final intAmount = amount.toInt();
    final formatter = intAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    return '$formatter ₽';
  }

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
