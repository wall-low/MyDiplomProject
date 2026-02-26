import 'package:flutter/foundation.dart';
import '../models/schedule_slot.dart';
import '../models/weekly_template.dart';
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
      debugPrint('[ScheduleService] ========== СОЗДАНИЕ СЛОТА ==========');
      debugPrint('[ScheduleService] 👤 TutorID: $tutorId');
      debugPrint('[ScheduleService] 📅 Date: $date');
      debugPrint('[ScheduleService] ⏰ Time: $startTime - $endTime');

      // Обнуляем время, оставляем только дату
      final dateOnly = DateTime(date.year, date.month, date.day);
      debugPrint('[ScheduleService] 📅 Date normalized: $dateOnly');

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

      final slotMap = slot.toMap();
      debugPrint('[ScheduleService] 📦 Slot data to send: $slotMap');
      debugPrint('[ScheduleService] 🌐 PocketBase URL: ${_pb.baseUrl}');
      debugPrint('[ScheduleService] 🔑 Auth valid: ${_pb.authStore.isValid}');

      // Создаем слот в PocketBase
      debugPrint('[ScheduleService] 🚀 Sending create request...');
      final record = await _pb.collection('slots').create(body: slotMap);

      debugPrint('[ScheduleService] ✅ Слот создан успешно!');
      debugPrint('[ScheduleService] 🆔 Record ID: ${record.id}');
      debugPrint('[ScheduleService] 📄 Record data: ${record.data}');
      debugPrint('[ScheduleService] ==========================================');

      notifyListeners(); // Уведомляем слушателей (ChangeNotifier)
    } catch (e, stackTrace) {
      debugPrint('[ScheduleService] ❌ ОШИБКА добавления слота: $e');
      debugPrint('[ScheduleService] 📋 StackTrace: $stackTrace');
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

  /// Получить слот по ID
  ///
  /// Проверяет существование слота перед бронированием
  /// Возвращает null, если слот не найден
  Future<ScheduleSlot?> getSlotById(String slotId) async {
    try {
      final record = await _pb.collection('slots').getOne(slotId);
      return ScheduleSlot.fromRecord(record);
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения слота $slotId: $e');
      return null;
    }
  }

  /// Забронировать слот (для ученика)
  ///
  /// НОВАЯ ЛОГИКА: Отправка запроса на бронирование
  /// - Устанавливаем bookingStatus = 'pending'
  /// - isBooked = true (временно занят)
  /// - Репетитор должен подтвердить или отклонить
  Future<void> bookSlot(String slotId, String studentId) async {
    try {
      // 1. Проверяем существование слота
      final slot = await getSlotById(slotId);

      if (slot == null) {
        throw Exception('Слот не найден. Возможно, он был удалён репетитором.');
      }

      // 2. Проверяем, не забронирован ли слот уже
      if (slot.isBooked) {
        throw Exception('Слот уже забронирован. Попробуйте выбрать другое время.');
      }

      // 3. Проверяем, не прошёл ли слот
      if (slot.isPast) {
        throw Exception('Это время уже прошло. Выберите другой слот.');
      }

      // 4. НОВОЕ: Создаём запрос на бронирование (pending)
      await _pb.collection('slots').update(
        slotId,
        body: {
          'isBooked': true, // Временно блокируем слот
          'studentId': studentId,
          'bookingStatus': 'pending', // Ожидает подтверждения репетитора
        },
      );

      debugPrint('[ScheduleService] Запрос на бронирование отправлен: $slotId для студента $studentId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка отправки запроса: $e');
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
          'bookingStatus': 'free', // Возвращаем статус в свободный
        },
      );

      debugPrint('[ScheduleService] Бронирование отменено: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка отмены бронирования: $e');
      rethrow;
    }
  }

  // ============================================================================
  // НОВЫЕ МЕТОДЫ: Система подтверждения бронирований
  // ============================================================================

  /// Получить все запросы на бронирование для репетитора (статус pending)
  ///
  /// Репетитор видит список всех учеников, которые запросили бронирование
  /// Фильтр: tutorId совпадает и bookingStatus = 'pending'
  Future<List<ScheduleSlot>> getPendingRequests(String tutorId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId" && bookingStatus="pending"',
            sort: '+date,+startTime', // Сортировка по дате и времени
            perPage: 500,
          );

      debugPrint('[ScheduleService] Запросов на бронирование: ${result.totalItems}');

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения запросов: $e');
      return [];
    }
  }

  /// Подтвердить запрос на бронирование (для репетитора)
  ///
  /// Алгоритм:
  /// 1. Устанавливаем bookingStatus = 'confirmed'
  /// 2. isBooked остаётся true
  /// 3. studentId остаётся
  ///
  /// После подтверждения слот считается полностью забронированным
  Future<void> approveBooking(String slotId) async {
    try {
      debugPrint('[ScheduleService] 🟢 Подтверждение запроса на слот: $slotId');

      await _pb.collection('slots').update(
        slotId,
        body: {
          'bookingStatus': 'confirmed',
          // isBooked и studentId уже установлены, не трогаем
        },
      );

      debugPrint('[ScheduleService] ✅ Запрос подтверждён: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка подтверждения запроса: $e');
      rethrow;
    }
  }

  /// Отклонить запрос на бронирование (для репетитора)
  ///
  /// Алгоритм:
  /// 1. Устанавливаем bookingStatus = 'free'
  /// 2. isBooked = false (освобождаем слот)
  /// 3. studentId = null (убираем ученика)
  ///
  /// После отклонения слот становится снова свободным для бронирования
  Future<void> rejectBooking(String slotId) async {
    try {
      debugPrint('[ScheduleService] 🔴 Отклонение запроса на слот: $slotId');

      await _pb.collection('slots').update(
        slotId,
        body: {
          'bookingStatus': 'free',
          'isBooked': false, // Освобождаем слот
          'studentId': null, // Убираем ученика
        },
      );

      debugPrint('[ScheduleService] ✅ Запрос отклонён, слот освобождён: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка отклонения запроса: $e');
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

  // ============================================================================
  // НОВЫЕ МЕТОДЫ: Генерация слотов из недельного шаблона
  // ============================================================================

  /// Сгенерировать слоты из недельного шаблона на N дней вперед
  ///
  /// Алгоритм:
  /// 1. Загружает активные шаблоны репетитора из weekly_templates
  /// 2. Проходит по каждому дню в диапазоне (daysAhead)
  /// 3. Для каждого дня находит соответствующие шаблоны по dayOfWeek
  /// 4. Создает слоты в таблице slots с флагом generatedFromTemplate=true
  /// 5. Пропускает, если слот уже существует (не дублирует)
  ///
  /// Параметры:
  /// - tutorId: ID репетитора
  /// - daysAhead: количество дней вперед для генерации (по умолчанию 28 = 4 недели)
  ///
  /// Возвращает: количество созданных слотов
  Future<int> generateSlotsFromTemplate({
    required String tutorId,
    int daysAhead = 28,
  }) async {
    int createdCount = 0;

    try {
      debugPrint('[ScheduleService] 🔄 Начало генерации слотов на $daysAhead дней');

      // 1. Загружаем активные шаблоны репетитора
      final templatesResult = await _pb.collection('weekly_templates').getList(
            filter: 'tutorId="$tutorId" && isActive=true',
            perPage: 500,
          );

      if (templatesResult.items.isEmpty) {
        debugPrint('[ScheduleService] ⚠️ Шаблон не настроен');
        return 0;
      }

      debugPrint('[ScheduleService] ✅ Загружено ${templatesResult.items.length} шаблонов');

      // 2. Группируем шаблоны по дням недели
      Map<int, List<WeeklyTemplate>> templatesByDay = {};
      for (var record in templatesResult.items) {
        final template = WeeklyTemplate.fromRecord(record);
        final day = template.dayOfWeek;
        templatesByDay[day] = templatesByDay[day] ?? [];
        templatesByDay[day]!.add(template);
      }

      // 3. Проходим по каждому дню в диапазоне
      final today = DateTime.now();

      for (int i = 0; i <= daysAhead; i++) {
        final date = today.add(Duration(days: i));
        final dateOnly = DateTime(date.year, date.month, date.day);
        final dayOfWeek = date.weekday; // 1=Пн, 7=Вс

        // Есть ли шаблон для этого дня недели?
        if (!templatesByDay.containsKey(dayOfWeek)) continue;

        // 4. Для каждого шаблона создаем слот
        for (var template in templatesByDay[dayOfWeek]!) {
          // Проверяем, существует ли уже слот на эту дату/время
          final dateStr = _formatDate(dateOnly);
          final existing = await _pb.collection('slots').getList(
                filter:
                    'tutorId="$tutorId" && date="$dateStr" && startTime="${template.startTime}" && endTime="${template.endTime}"',
                perPage: 1,
              );

          if (existing.items.isEmpty) {
            // Слота нет → создаем
            await _pb.collection('slots').create(body: {
              'tutorId': tutorId,
              'date': dateStr,
              'startTime': template.startTime,
              'endTime': template.endTime,
              'isBooked': false,
              'isPaid': false,
              'generatedFromTemplate': true,
              'templateId': template.id,
            });

            createdCount++;
            debugPrint(
                '[ScheduleService] ✅ Создан слот: $dateStr ${template.startTime}-${template.endTime}');
          }
        }
      }

      debugPrint('[ScheduleService] ✅ Генерация завершена: создано $createdCount слотов');

      notifyListeners();
      return createdCount;
    } catch (e, stackTrace) {
      debugPrint('[ScheduleService] ❌ Ошибка генерации слотов:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');
      return createdCount;
    }
  }

  /// Проверить и сгенерировать слоты, если их недостаточно
  ///
  /// Алгоритм "скользящего окна":
  /// 1. Находит самый дальний слот репетитора
  /// 2. Вычисляет, на сколько дней вперед есть слоты
  /// 3. Если слотов меньше чем на minDaysAhead дней → генерирует еще на daysToGenerate
  ///
  /// Параметры:
  /// - tutorId: ID репетитора
  /// - minDaysAhead: минимальное количество дней вперед (по умолчанию 14)
  /// - daysToGenerate: сколько дней генерировать при нехватке (по умолчанию 28)
  ///
  /// Возвращает: true, если генерация была выполнена
  Future<bool> checkAndGenerateSlots(
    String tutorId, {
    int minDaysAhead = 14,
    int daysToGenerate = 28,
  }) async {
    try {
      debugPrint('[ScheduleService] 🔍 Проверка необходимости генерации слотов');

      // 1. Находим самый дальний слот
      final farthestSlotResult = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId"',
            sort: '-date', // Сортировка по убыванию
            perPage: 1,
          );

      if (farthestSlotResult.items.isEmpty) {
        // Слотов вообще нет → генерируем
        debugPrint('[ScheduleService] ⚠️ Слотов нет, генерируем на $daysToGenerate дней');
        await generateSlotsFromTemplate(
            tutorId: tutorId, daysAhead: daysToGenerate);
        return true;
      }

      // 2. Вычисляем, на сколько дней вперед есть слоты
      final farthestDate = DateTime.parse(farthestSlotResult.items.first.data['date']);
      final today = DateTime.now();
      final daysAhead = farthestDate.difference(today).inDays;

      debugPrint('[ScheduleService] 📊 Слоты есть на $daysAhead дней вперед');

      // 3. Если осталось меньше minDaysAhead дней → генерируем еще
      if (daysAhead < minDaysAhead) {
        debugPrint(
            '[ScheduleService] ⚠️ Слотов мало (<$minDaysAhead дней), генерируем еще на $daysToGenerate дней');
        await generateSlotsFromTemplate(
            tutorId: tutorId, daysAhead: daysToGenerate);
        return true;
      } else {
        debugPrint('[ScheduleService] ✅ Слотов достаточно');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('[ScheduleService] ❌ Ошибка проверки слотов:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');
      return false;
    }
  }

  /// Удалить все сгенерированные свободные слоты (для пересоздания)
  ///
  /// Используется при изменении шаблона:
  /// 1. Удаляет все свободные слоты, созданные из шаблона
  /// 2. НЕ трогает забронированные слоты
  /// 3. После этого вызывается generateSlotsFromTemplate() для создания новых
  ///
  /// Возвращает: количество удаленных слотов
  Future<int> clearGeneratedFreeSlots(String tutorId) async {
    int deletedCount = 0;

    try {
      debugPrint('[ScheduleService] 🗑️ Очистка сгенерированных свободных слотов');

      // Находим все сгенерированные свободные слоты в будущем
      final today = DateTime.now();
      final todayStr = _formatDate(today);

      final result = await _pb.collection('slots').getList(
            filter:
                'tutorId="$tutorId" && generatedFromTemplate=true && isBooked=false && date>="$todayStr"',
            perPage: 500,
          );

      debugPrint('[ScheduleService] 🔍 Найдено ${result.items.length} слотов для удаления');

      // Удаляем каждый слот
      for (var record in result.items) {
        await _pb.collection('slots').delete(record.id);
        deletedCount++;
      }

      debugPrint('[ScheduleService] ✅ Удалено $deletedCount слотов');

      notifyListeners();
      return deletedCount;
    } catch (e, stackTrace) {
      debugPrint('[ScheduleService] ❌ Ошибка очистки слотов:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');
      return deletedCount;
    }
  }

  /// Получить забронированные слоты, которые не вписываются в новый шаблон
  ///
  /// Используется для предупреждения репетитора при изменении шаблона
  /// Возвращает список забронированных слотов в будущем
  Future<List<ScheduleSlot>> getBookedFutureSlots(String tutorId) async {
    try {
      final today = DateTime.now();
      final todayStr = _formatDate(today);

      final result = await _pb.collection('slots').getList(
            filter:
                'tutorId="$tutorId" && isBooked=true && date>="$todayStr"',
            sort: '+date,+startTime',
            perPage: 500,
          );

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка получения забронированных слотов: $e');
      return [];
    }
  }

  /// Форматирование даты для PocketBase (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
