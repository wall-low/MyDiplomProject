import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import 'pocketbase_service.dart';

/// Сервис для работы с платежами (имитация для диплома)
///
/// Работает с коллекцией payments в PocketBase
/// Управляет mock-оплатой занятий
class PaymentService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  /// Создать платёж (имитация оплаты)
  ///
  /// ВАЖНО: Это mock-оплата для диплома, без реальных денег!
  ///
  /// Параметры:
  /// - studentId: ID ученика (кто платит)
  /// - tutorId: ID репетитора (кому платят)
  /// - slotId: ID слота (за какое занятие)
  /// - amount: сумма в рублях
  ///
  /// Возвращает: созданный Payment или null при ошибке
  ///
  /// Процесс:
  /// 1. Создаём запись в payments со статусом "pending"
  /// 2. Сразу обновляем статус на "completed" (имитация успешной оплаты)
  /// 3. Обновляем slot.isPaid = true (делается в вызывающем коде)
  Future<Payment?> createPayment({
    required String studentId,
    required String tutorId,
    required String slotId,
    required double amount,
  }) async {
    try {
      debugPrint('[PaymentService] 💳 Создание платежа...');
      debugPrint('[PaymentService] 👤 Student: $studentId');
      debugPrint('[PaymentService] 👨‍🏫 Tutor: $tutorId');
      debugPrint('[PaymentService] 📅 Slot: $slotId');
      debugPrint('[PaymentService] 💰 Amount: $amount ₽');

      // Подготавливаем данные
      final body = {
        'studentId': studentId,
        'tutorId': tutorId,
        'slotId': slotId,
        'amount': amount,
        'status': 'pending', // Создаём в статусе "ожидает оплаты"
      };

      // Создаём запись в PocketBase
      final record = await _pb.collection('payments').create(body: body);

      debugPrint('[PaymentService] ✅ Платёж создан: ${record.id}');

      // ИМИТАЦИЯ: сразу же "оплачиваем" (меняем статус на completed)
      // В реальном приложении здесь был бы вызов платёжного API
      final completedRecord = await _pb.collection('payments').update(
            record.id,
            body: {'status': 'completed'},
          );

      debugPrint('[PaymentService] ✅ Платёж успешно "оплачен" (mock)');

      // Уведомляем слушателей
      notifyListeners();

      return Payment.fromRecord(completedRecord);
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка создания платежа: $e');
      return null;
    }
  }

  /// Получить платёж по ID
  ///
  /// paymentId - ID записи в коллекции payments
  ///
  /// Возвращает: Payment или null, если не найден
  Future<Payment?> getPaymentById(String paymentId) async {
    try {
      final record = await _pb.collection('payments').getOne(paymentId);
      return Payment.fromRecord(record);
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка получения платежа: $e');
      return null;
    }
  }

  /// Получить все платежи ученика
  ///
  /// studentId - ID ученика в коллекции users
  ///
  /// Возвращает: список Payment, отсортированный по дате (новые сначала)
  Future<List<Payment>> getPaymentsByStudent(String studentId) async {
    try {
      debugPrint('[PaymentService] 🔍 Получение платежей ученика: $studentId');

      // Запрос с фильтром и сортировкой
      final result = await _pb.collection('payments').getList(
            filter: 'studentId="$studentId"',
            sort: '-created', // Сортировка по дате (новые сначала)
            perPage: 100, // Лимит на 100 записей
          );

      final payments = result.items.map((r) => Payment.fromRecord(r)).toList();

      debugPrint('[PaymentService] ✅ Найдено платежей: ${payments.length}');

      return payments;
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка получения платежей ученика: $e');
      return [];
    }
  }

  /// Получить все платежи репетитора
  ///
  /// tutorId - ID репетитора в коллекции users
  ///
  /// Возвращает: список Payment, отсортированный по дате (новые сначала)
  Future<List<Payment>> getPaymentsByTutor(String tutorId) async {
    try {
      debugPrint('[PaymentService] 🔍 Получение платежей репетитора: $tutorId');

      // Запрос с фильтром и сортировкой
      final result = await _pb.collection('payments').getList(
            filter: 'tutorId="$tutorId"',
            sort: '-created', // Сортировка по дате (новые сначала)
            perPage: 100, // Лимит на 100 записей
          );

      final payments = result.items.map((r) => Payment.fromRecord(r)).toList();

      debugPrint('[PaymentService] ✅ Найдено платежей: ${payments.length}');

      return payments;
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка получения платежей репетитора: $e');
      return [];
    }
  }

  /// Получить платёж по slotId
  ///
  /// slotId - ID слота в коллекции slots
  ///
  /// Возвращает: Payment или null, если платёж не найден
  ///
  /// Используется для проверки, оплачен ли конкретный слот
  Future<Payment?> getPaymentBySlot(String slotId) async {
    try {
      debugPrint('[PaymentService] 🔍 Поиск платежа для слота: $slotId');

      // Запрос с фильтром
      final result = await _pb.collection('payments').getList(
            filter: 'slotId="$slotId"',
            perPage: 1, // Ожидаем только 1 платёж на слот
          );

      if (result.items.isEmpty) {
        debugPrint('[PaymentService] ℹ️ Платёж для слота не найден');
        return null;
      }

      final payment = Payment.fromRecord(result.items.first);
      debugPrint('[PaymentService] ✅ Платёж найден: ${payment.id}');

      return payment;
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка поиска платежа по слоту: $e');
      return null;
    }
  }

  /// Получить общую сумму заработка репетитора
  ///
  /// tutorId - ID репетитора
  ///
  /// Возвращает: сумму всех completed платежей
  Future<double> getTutorTotalEarnings(String tutorId) async {
    try {
      final payments = await getPaymentsByTutor(tutorId);

      // Суммируем только completed платежи
      final total = payments
          .where((p) => p.isCompleted)
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      debugPrint('[PaymentService] 💰 Общий заработок репетитора: $total ₽');

      return total;
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка расчёта заработка: $e');
      return 0.0;
    }
  }

  /// Получить общую сумму расходов ученика
  ///
  /// studentId - ID ученика
  ///
  /// Возвращает: сумму всех completed платежей
  Future<double> getStudentTotalSpending(String studentId) async {
    try {
      final payments = await getPaymentsByStudent(studentId);

      // Суммируем только completed платежи
      final total = payments
          .where((p) => p.isCompleted)
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      debugPrint('[PaymentService] 💸 Общие расходы ученика: $total ₽');

      return total;
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка расчёта расходов: $e');
      return 0.0;
    }
  }

  /// Получить статистику платежей репетитора
  ///
  /// Возвращает: Map с количеством платежей по статусам
  ///
  /// Пример: {"completed": 10, "pending": 2, "failed": 1}
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

      debugPrint('[PaymentService] 📊 Статистика платежей: $stats');

      return stats;
    } catch (e) {
      debugPrint('[PaymentService] ❌ Ошибка получения статистики: $e');
      return {'completed': 0, 'pending': 0, 'failed': 0};
    }
  }

  /// Проверить, оплачен ли слот
  ///
  /// slotId - ID слота
  ///
  /// Возвращает: true если существует completed платёж для этого слота
  Future<bool> isSlotPaid(String slotId) async {
    final payment = await getPaymentBySlot(slotId);
    return payment != null && payment.isCompleted;
  }
}
