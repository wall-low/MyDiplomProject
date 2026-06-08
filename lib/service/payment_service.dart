import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import 'pocketbase_service.dart';
import 'tutor_profile_service.dart';

class PaymentService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  Future<Payment?> createPayment({
    required String studentId,
    required String tutorId,
    required String slotId,
    required double amount,
  }) async {
    try {
      debugPrint('[PaymentService] Создание платежа...');
      debugPrint('[PaymentService] Student: $studentId');
      debugPrint('[PaymentService] Tutor: $tutorId');
      debugPrint('[PaymentService] Slot: $slotId');
      debugPrint('[PaymentService] Amount: $amount ₽');

      final body = {
        'studentId': studentId,
        'tutorId': tutorId,
        'slotId': slotId,
        'amount': amount,
        'status': 'pending',
      };

      final record = await _pb.collection('payments').create(body: body);

      debugPrint('[PaymentService] Платёж создан: ${record.id}');

      final completedRecord = await _pb.collection('payments').update(
            record.id,
            body: {'status': 'completed'},
          );

      debugPrint('[PaymentService] Платёж успешно "оплачен" (mock)');

      try {
        final tutorProfileService = TutorProfileService();
        final profile = await tutorProfileService.getTutorProfileByUserId(tutorId);
        if (profile != null) {
          await tutorProfileService.incrementPaidLessons(profile.id);
          debugPrint('[PaymentService] totalPaidLessons увеличен для репетитора: $tutorId');
        }
      } catch (e) {
        debugPrint('[PaymentService] Не удалось обновить счётчик занятия: $e');
      }

      notifyListeners();

      return Payment.fromRecord(completedRecord);
    } catch (e) {
      debugPrint('[PaymentService] Ошибка создания платежа: $e');
      return null;
    }
  }

  Future<Payment?> getPaymentById(String paymentId) async {
    try {
      final record = await _pb.collection('payments').getOne(paymentId);
      return Payment.fromRecord(record);
    } catch (e) {
      debugPrint('[PaymentService] Ошибка получения платежа: $e');
      return null;
    }
  }

  Future<List<Payment>> getPaymentsByStudent(String studentId) async {
    try {
      debugPrint('[PaymentService] Получение платежей ученика: $studentId');

      final result = await _pb.collection('payments').getList(
            filter: 'studentId="$studentId"',
            sort: '-created',
            perPage: 100,
          );

      final payments = result.items.map((r) => Payment.fromRecord(r)).toList();

      debugPrint('[PaymentService] Найдено платежей: ${payments.length}');

      return payments;
    } catch (e) {
      debugPrint('[PaymentService] Ошибка получения платежей ученика: $e');
      return [];
    }
  }

  Future<List<Payment>> getPaymentsByTutor(String tutorId) async {
    try {
      debugPrint('[PaymentService] Получение платежей репетитора: $tutorId');

      final result = await _pb.collection('payments').getList(
            filter: 'tutorId="$tutorId"',
            sort: '-created',
            perPage: 100,
          );

      final payments = result.items.map((r) => Payment.fromRecord(r)).toList();

      debugPrint('[PaymentService] Найдено платежей: ${payments.length}');

      return payments;
    } catch (e) {
      debugPrint('[PaymentService] Ошибка получения платежей репетитора: $e');
      return [];
    }
  }

  Future<Payment?> getPaymentBySlot(String slotId) async {
    try {
      debugPrint('[PaymentService] Поиск платежа для слота: $slotId');

      final result = await _pb.collection('payments').getList(
            filter: 'slotId="$slotId"',
            perPage: 1,
          );

      if (result.items.isEmpty) {
        debugPrint('[PaymentService] Платёж для слота не найден');
        return null;
      }

      final payment = Payment.fromRecord(result.items.first);
      debugPrint('[PaymentService] Платёж найден: ${payment.id}');

      return payment;
    } catch (e) {
      debugPrint('[PaymentService] Ошибка поиска платежа по слоту: $e');
      return null;
    }
  }

  Future<double> getTutorTotalEarnings(String tutorId) async {
    try {
      final payments = await getPaymentsByTutor(tutorId);

      final total = payments
          .where((p) => p.isCompleted)
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      debugPrint('[PaymentService] Общий заработок репетитора: $total ₽');

      return total;
    } catch (e) {
      debugPrint('[PaymentService] Ошибка расчёта заработка: $e');
      return 0.0;
    }
  }

  Future<double> getStudentTotalSpending(String studentId) async {
    try {
      final payments = await getPaymentsByStudent(studentId);

      final total = payments
          .where((p) => p.isCompleted)
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      debugPrint('[PaymentService] Общие расходы ученика: $total ₽');

      return total;
    } catch (e) {
      debugPrint('[PaymentService] Ошибка расчёта расходов: $e');
      return 0.0;
    }
  }

  Future<Map<String, int>> getTutorPaymentStats(String tutorId) async {
    try {
      final payments = await getPaymentsByTutor(tutorId);

      final stats = <String, int>{
        'completed': 0,
        'pending': 0,
        'failed': 0,
      };

      for (final payment in payments) {
        stats[payment.status] = (stats[payment.status] ?? 0) + 1;
      }

      debugPrint('[PaymentService] Статистика платежей: $stats');

      return stats;
    } catch (e) {
      debugPrint('[PaymentService] Ошибка получения статистики: $e');
      return {'completed': 0, 'pending': 0, 'failed': 0};
    }
  }

  Future<Payment?> createExternalPayment({
    required String studentId,
    required String tutorId,
    required String slotId,
    required double amount,
  }) async {
    try {
      debugPrint('[PaymentService] Создание внешнего платежа...');

      final record = await _pb.collection('payments').create(body: {
        'studentId': studentId,
        'tutorId': tutorId,
        'slotId': slotId,
        'amount': amount,
        'status': 'completed',
      });

      debugPrint('[PaymentService] ✅ Внешний платёж создан: ${record.id}');

      try {
        final tutorProfileService = TutorProfileService();
        final profile = await tutorProfileService.getTutorProfileByUserId(tutorId);
        if (profile != null) {
          await tutorProfileService.incrementPaidLessons(profile.id);
        }
      } catch (e) {
        debugPrint('[PaymentService] Не удалось обновить счётчик: $e');
      }

      notifyListeners();
      return Payment.fromRecord(record);
    } catch (e) {
      debugPrint('[PaymentService] Ошибка создания внешнего платежа: $e');
      return null;
    }
  }

  Future<Payment?> createManualPayment({
    required String tutorId,
    required double amount,
    String note = '',
  }) async {
    try {
      final record = await _pb.collection('payments').create(body: {
        'studentId': note,
        'tutorId': tutorId,
        'slotId': 'manual',
        'amount': amount,
        'status': 'completed',
      });
      notifyListeners();
      return Payment.fromRecord(record);
    } catch (e) {
      debugPrint('[PaymentService] Ошибка создания ручного платежа: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getTutorThisMonthStats(String tutorId) async {
    try {
      final payments = await getPaymentsByTutor(tutorId);
      final now = DateTime.now();
      final thisMonth = payments.where((p) =>
          p.isCompleted &&
          p.created.year == now.year &&
          p.created.month == now.month);
      final earnings = thisMonth.fold<double>(0.0, (sum, p) => sum + p.amount);
      return {'earnings': earnings, 'count': thisMonth.length};
    } catch (e) {
      return {'earnings': 0.0, 'count': 0};
    }
  }

  Future<bool> isSlotPaid(String slotId) async {
    final payment = await getPaymentBySlot(slotId);
    return payment != null && payment.isCompleted;
  }
}
