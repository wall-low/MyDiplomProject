import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/schedule_slot.dart';
import 'pocketbase_service.dart';

/// Сервис для работы с расписанием репетиторов (слоты времени)
///
/// Мигрировано с Cloud Firestore на PocketBase
/// Причина: риск блокировки Firebase в РФ перед защитой диплома
class ScheduleService extends ChangeNotifier {
  // ИЗМЕНЕНИЕ 1: Заменили Firestore на PocketBase
  //
  // БЫЛО:
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  //
  // СТАЛО:
  final _pb = PocketBaseService().client;

  /// Получить все слоты преподавателя
  ///
  /// БЫЛО (Firestore):
  /// Stream<List<ScheduleSlot>> - реактивный поток
  ///
  /// СТАЛО (PocketBase):
  /// Future<List<ScheduleSlot>> - одноразовый запрос
  ///
  /// Для реактивности можно добавить subscribe() позже
  Future<List<ScheduleSlot>> getTutorSchedule(String tutorId) async {
    try {
      // ИЗМЕНЕНИЕ 2: Запрос слотов по tutorId
      //
      // БЫЛО (Firestore):
      // _firestore.collection('slots')
      //   .where('tutorId', isEqualTo: tutorId)
      //   .orderBy('date').orderBy('startTime').snapshots()
      //
      // СТАЛО (PocketBase):
      // _pb.collection('slots').getList(
      //   filter: 'tutorId="$tutorId"',
      //   sort: '+date,+startTime'  // Множественная сортировка
      // )
      //
      // Отличия:
      // - filter вместо where
      // - sort: '+date,+startTime' - сортировка по нескольким полям
      //   '+' = ascending (по возрастанию)
      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId"',
            sort: '+date,+startTime', // Сначала по дате, потом по времени
            perPage: 500, // Ограничение для производительности
          );

      // Преобразуем RecordModel в ScheduleSlot
      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения расписания: $e');
      return [];
    }
  }

  /// Получить слоты преподавателя на конкретную дату
  ///
  /// ВАЖНО: Фильтрация по дате
  /// В Firestore использовали клиентскую фильтрацию (в коде)
  /// В PocketBase можем фильтровать на сервере через filter
  Future<List<ScheduleSlot>> getTutorScheduleByDate(
    String tutorId,
    DateTime date,
  ) async {
    try {
      // Нормализуем дату (только год, месяц, день, без времени)
      final targetDate = DateTime(date.year, date.month, date.day);

      debugPrint('📅 Target date: $targetDate');

      // ИЗМЕНЕНИЕ 3: Фильтрация по дате на сервере
      //
      // БЫЛО (Firestore):
      // 1. Получали все слоты репетитора
      // 2. Фильтровали по дате в коде (client-side)
      //
      // СТАЛО (PocketBase):
      // Фильтруем сразу на сервере через filter
      //
      // PocketBase фильтр по дате:
      // date >= '2024-01-15' && date < '2024-01-16'
      // Это получит все слоты за 15 января
      final dateStr = targetDate.toIso8601String().split('T')[0]; // "2024-01-15"
      final nextDayStr =
          targetDate.add(Duration(days: 1)).toIso8601String().split('T')[0]; // "2024-01-16"

      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId" && date >= "$dateStr" && date < "$nextDayStr"',
            sort: '+startTime,+endTime', // Сортировка по времени
            perPage: 100,
          );

      debugPrint('🔍 Total slots for date: ${result.totalItems}');

      // Преобразуем RecordModel в ScheduleSlot
      final slots = result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();

      debugPrint('✅ Filtered slots: ${slots.length}');

      return slots;
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения слотов по дате: $e');
      return [];
    }
  }

  /// Добавить новый слот
  ///
  /// ИЗМЕНЕНИЕ 4: create() вместо add()
  ///
  /// БЫЛО (Firestore):
  /// await _firestore.collection('slots').add(slot.toMap())
  ///
  /// СТАЛО (PocketBase):
  /// await _pb.collection('slots').create(body: slot.toMap())
  Future<void> addSlot({
    required String tutorId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      // Обнуляем время, оставляем только дату
      final dateOnly = DateTime(date.year, date.month, date.day);

      // ИЗМЕНЕНИЕ 5: Timestamp.now() → DateTime.now()
      //
      // БЫЛО:
      // createdAt: Timestamp.now()
      //
      // СТАЛО:
      // createdAt не нужен - PocketBase автоматически создает поле created
      final slot = ScheduleSlot(
        id: '', // ID будет создан PocketBase
        tutorId: tutorId,
        date: dateOnly,
        startTime: startTime,
        endTime: endTime,
        isBooked: false,
        createdAt: DateTime.now(), // Для модели
      );

      // Создаем слот в PocketBase
      await _pb.collection('slots').create(body: slot.toMap());

      debugPrint('[ScheduleService] Слот создан: $dateOnly $startTime-$endTime');
      notifyListeners(); // Уведомляем слушателей (ChangeNotifier)
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка добавления слота: $e');
      rethrow;
    }
  }

  /// Удалить слот
  ///
  /// ИЗМЕНЕНИЕ 6: delete(id) вместо doc(id).delete()
  ///
  /// БЫЛО (Firestore):
  /// await _firestore.collection('slots').doc(slotId).delete()
  ///
  /// СТАЛО (PocketBase):
  /// await _pb.collection('slots').delete(slotId)
  ///
  /// API проще - просто передаем ID
  Future<void> deleteSlot(String slotId) async {
    try {
      await _pb.collection('slots').delete(slotId);

      debugPrint('[ScheduleService] Слот удален: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка удаления слота: $e');
      rethrow;
    }
  }

  /// Обновить слот
  ///
  /// ИЗМЕНЕНИЕ 7: update(id, body: {}) вместо doc(id).update({})
  ///
  /// БЫЛО (Firestore):
  /// await _firestore.collection('slots').doc(slotId).update(updates)
  ///
  /// СТАЛО (PocketBase):
  /// await _pb.collection('slots').update(slotId, body: updates)
  Future<void> updateSlot({
    required String slotId,
    DateTime? date,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final updates = <String, dynamic>{};

      // ИЗМЕНЕНИЕ 8: Timestamp.fromDate() → toIso8601String()
      //
      // БЫЛО:
      // if (date != null) updates['date'] = Timestamp.fromDate(date);
      //
      // СТАЛО:
      // if (date != null) updates['date'] = date.toIso8601String();
      if (date != null) {
        // Нормализуем дату (только год, месяц, день)
        final dateOnly = DateTime(date.year, date.month, date.day);
        updates['date'] = dateOnly.toIso8601String();
      }
      if (startTime != null) updates['startTime'] = startTime;
      if (endTime != null) updates['endTime'] = endTime;

      if (updates.isNotEmpty) {
        await _pb.collection('slots').update(slotId, body: updates);

        debugPrint('[ScheduleService] Слот обновлен: $slotId');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка обновления слота: $e');
      rethrow;
    }
  }

  /// Забронировать слот (для ученика)
  ///
  /// Ученик бронирует свободный слот репетитора
  /// Помечаем слот как занятый и сохраняем ID ученика
  Future<void> bookSlot(String slotId, String studentId) async {
    try {
      await _pb.collection('slots').update(
        slotId,
        body: {
          'isBooked': true,
          'studentId': studentId,
        },
      );

      debugPrint('[ScheduleService] Слот забронирован: $slotId для студента $studentId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка бронирования слота: $e');
      rethrow;
    }
  }

  /// Отменить бронирование
  ///
  /// Освобождаем слот - убираем флаг isBooked и studentId
  Future<void> cancelBooking(String slotId) async {
    try {
      await _pb.collection('slots').update(
        slotId,
        body: {
          'isBooked': false,
          'studentId': null, // Убираем ID ученика
        },
      );

      debugPrint('[ScheduleService] Бронирование отменено: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка отмены бронирования: $e');
      rethrow;
    }
  }

  /// Получить доступные (не забронированные) слоты преподавателя
  ///
  /// ИЗМЕНЕНИЕ 9: Фильтр через filter вместо where
  ///
  /// БЫЛО (Firestore):
  /// .where('tutorId', isEqualTo: tutorId)
  /// .where('isBooked', isEqualTo: false)
  ///
  /// СТАЛО (PocketBase):
  /// filter: 'tutorId="$tutorId" && isBooked=false'
  ///
  /// Можно комбинировать несколько условий через &&
  Future<List<ScheduleSlot>> getAvailableSlots(String tutorId) async {
    try {
      // Получаем только свободные слоты
      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId" && isBooked=false',
            sort: '+date,+startTime', // Сортировка по дате и времени
            perPage: 500,
          );

      debugPrint('[ScheduleService] Доступных слотов: ${result.totalItems}');

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения доступных слотов: $e');
      return [];
    }
  }

  /// ДОПОЛНИТЕЛЬНО: Получить слоты студента (забронированные им)
  ///
  /// НОВЫЙ МЕТОД - может быть полезен для отображения "Мои занятия"
  Future<List<ScheduleSlot>> getStudentSlots(String studentId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'studentId="$studentId" && isBooked=true',
            sort: '+date,+startTime',
            perPage: 500,
          );

      debugPrint('[ScheduleService] Слотов у студента: ${result.totalItems}');

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения слотов студента: $e');
      return [];
    }
  }
}

/// ВАЖНЫЕ ЗАМЕЧАНИЯ:
///
/// 1. СТРУКТУРА ДАННЫХ:
/// - Firestore и PocketBase практически идентичны для slots
/// - Основное отличие: Timestamp → DateTime (ISO 8601)
///
/// 2. РЕАКТИВНОСТЬ:
/// - Firestore: .snapshots() - автоматический Stream
/// - PocketBase: .getList() - Future (одноразовый запрос)
/// - Для реактивности можно добавить .subscribe() позже
///
/// 3. ФИЛЬТРАЦИЯ ПО ДАТЕ:
/// - Firestore: клиентская фильтрация (в коде)
/// - PocketBase: серверная фильтрация через filter
/// - Преимущество: меньше данных передается по сети
///
/// 4. СОРТИРОВКА:
/// - Firestore: .orderBy('field1').orderBy('field2')
/// - PocketBase: sort: '+field1,+field2'
/// - '+' = ascending, '-' = descending
///
/// 5. OPERATIONS:
/// - Firestore: .add(), .doc(id).update(), .doc(id).delete()
/// - PocketBase: .create(), .update(id, body: {}), .delete(id)
/// - API проще и единообразнее
///
/// 6. TODO для улучшения:
/// - Добавить realtime через subscribe() для getTutorSchedule()
/// - Добавить пагинацию для репетиторов с большим количеством слотов
/// - Кешировать результаты для производительности
