import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/schedule_slot.dart';
import '../models/weekly_template.dart';
import 'pocketbase_service.dart';

class ScheduleService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  Future<List<ScheduleSlot>> getTutorSchedule(String tutorId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId"',
            sort: '+date,+startTime',
            perPage: 500,
          );

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения расписания: $e');
      return [];
    }
  }

  Future<List<ScheduleSlot>> getTutorScheduleByDate(
    String tutorId,
    DateTime date,
  ) async {
    try {
      final targetDate = DateTime(date.year, date.month, date.day);

      debugPrint('📅 Target date: $targetDate');

      final dateStr = targetDate.toIso8601String().split('T')[0];
      final nextDayStr =
          targetDate.add(Duration(days: 1)).toIso8601String().split('T')[0];

      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId" && date >= "$dateStr" && date < "$nextDayStr"',
            sort: '+startTime,+endTime',
            perPage: 100,
          );

      debugPrint('🔍 Total slots for date: ${result.totalItems}');

      final slots = result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();

      debugPrint('✅ Filtered slots: ${slots.length}');

      return slots;
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения слотов по дате: $e');
      return [];
    }
  }

  Future<void> addSlot({
    required String tutorId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? subject,
  }) async {
    try {
      debugPrint('[ScheduleService] ========== СОЗДАНИЕ СЛОТА ==========');
      debugPrint('[ScheduleService] 👤 TutorID: $tutorId');
      debugPrint('[ScheduleService] 📅 Date: $date');
      debugPrint('[ScheduleService] ⏰ Time: $startTime - $endTime');
      if (subject != null) debugPrint('[ScheduleService] 📚 Subject: $subject');

      final dateOnly = DateTime(date.year, date.month, date.day);
      debugPrint('[ScheduleService] 📅 Date normalized: $dateOnly');

      final slot = ScheduleSlot(
        id: '',
        tutorId: tutorId,
        date: dateOnly,
        startTime: startTime,
        endTime: endTime,
        isBooked: false,
        createdAt: DateTime.now(),
        subject: subject,
      );

      final slotMap = slot.toMap();
      debugPrint('[ScheduleService] 📦 Slot data to send: $slotMap');
      debugPrint('[ScheduleService] 🌐 PocketBase URL: ${_pb.baseUrl}');
      debugPrint('[ScheduleService] 🔑 Auth valid: ${_pb.authStore.isValid}');

      debugPrint('[ScheduleService] 🚀 Sending create request...');
      final record = await _pb.collection('slots').create(body: slotMap);

      debugPrint('[ScheduleService] ✅ Слот создан успешно!');
      debugPrint('[ScheduleService] 🆔 Record ID: ${record.id}');
      debugPrint('[ScheduleService] 📄 Record data: ${record.data}');
      debugPrint('[ScheduleService] ==========================================');

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[ScheduleService] ❌ ОШИБКА добавления слота: $e');
      debugPrint('[ScheduleService] 📋 StackTrace: $stackTrace');
      rethrow;
    }
  }

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

  Future<void> updateSlot({
    required String slotId,
    DateTime? date,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (date != null) {
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

  Future<void> updateSlotFields(String slotId, Map<String, dynamic> updates) async {
    try {
      if (updates.isEmpty) {
        debugPrint('[ScheduleService] Нет полей для обновления');
        return;
      }

      await _pb.collection('slots').update(slotId, body: updates);

      debugPrint('[ScheduleService] Слот обновлен: $slotId, поля: ${updates.keys.join(", ")}');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка обновления полей слота: $e');
      rethrow;
    }
  }

  Future<ScheduleSlot?> getSlotById(String slotId) async {
    try {
      debugPrint('[ScheduleService] 🔍 Запрос слота: $slotId');
      debugPrint('[ScheduleService] 👤 Текущий пользователь: ${_pb.authStore.model?.id}');

      final record = await _pb.collection('slots').getOne(slotId);

      debugPrint('[ScheduleService] ✅ Слот получен: ${record.id}');
      debugPrint('[ScheduleService] 📋 Данные: tutorId=${record.data['tutorId']}, studentId=${record.data['studentId']}');

      return ScheduleSlot.fromRecord(record);
    } catch (e, stackTrace) {
      debugPrint('[ScheduleService] ❌ Ошибка получения слота $slotId');
      debugPrint('[ScheduleService] 🔥 Тип ошибки: ${e.runtimeType}');
      debugPrint('[ScheduleService] 📝 Сообщение: $e');
      debugPrint('[ScheduleService] 📚 StackTrace: ${stackTrace.toString().substring(0, 500)}');
      return null;
    }
  }

  Future<void> bookSlot(String slotId, String studentId) async {
    try {
      final slot = await getSlotById(slotId);

      if (slot == null) {
        throw Exception('Слот не найден. Возможно, он был удалён репетитором.');
      }

      if (slot.isBooked) {
        throw Exception('Слот уже забронирован. Попробуйте выбрать другое время.');
      }

      if (slot.isPast) {
        throw Exception('Это время уже прошло. Выберите другой слот.');
      }

      await _pb.collection('slots').update(
        slotId,
        body: {
          'isBooked': true,
          'studentId': studentId,
          'bookingStatus': 'pending',
        },
      );

      debugPrint('[ScheduleService] Запрос на бронирование отправлен: $slotId для студента $studentId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка отправки запроса: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String slotId) async {
    try {
      await _pb.collection('slots').update(
        slotId,
        body: {
          'isBooked': false,
          'studentId': null,
          'bookingStatus': 'free',
        },
      );

      debugPrint('[ScheduleService] Бронирование отменено: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка отмены бронирования: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> bookRecurringSlots({
    required ScheduleSlot initialSlot,
    required String studentId,
  }) async {
    int successCount = 0;
    List<String> errors = [];

    try {
      final groupId = 'recurring_${DateTime.now().millisecondsSinceEpoch}_${studentId.substring(0, 8)}';

      debugPrint('[ScheduleService] 🔄 Постоянное расписание');
      debugPrint('[ScheduleService] 🆔 Group ID: $groupId');
      debugPrint('[ScheduleService] 📅 Начальная дата: ${initialSlot.date}');
      debugPrint('[ScheduleService] ⏰ Время: ${initialSlot.startTime} - ${initialSlot.endTime}');

      final weekday = initialSlot.date.weekday;
      debugPrint('[ScheduleService] 📆 День недели: $weekday');

      final endDate = DateTime.now().add(const Duration(days: 90));

      final allSlots = await getTutorSchedule(initialSlot.tutorId);

      final matchingSlots = allSlots.where((slot) {
        return slot.date.weekday == weekday &&
               slot.startTime == initialSlot.startTime &&
               slot.endTime == initialSlot.endTime &&
               !slot.isBooked &&
               !slot.isPast &&
               slot.date.isBefore(endDate) &&
               slot.date.isAfter(DateTime.now().subtract(const Duration(days: 1)));
      }).toList();

      debugPrint('[ScheduleService] 🎯 Найдено подходящих слотов: ${matchingSlots.length}');

      for (final slot in matchingSlots) {
        try {
          await _pb.collection('slots').update(
            slot.id,
            body: {
              'isBooked': true,
              'studentId': studentId,
              'bookingStatus': 'pending',
              'isRecurring': true,
              'recurringGroupId': groupId,
            },
          );
          successCount++;
          debugPrint('[ScheduleService] ✅ Забронирован: ${slot.date.toString().split(' ')[0]}');
        } catch (e) {
          debugPrint('[ScheduleService] ❌ Ошибка бронирования ${slot.date}: $e');
          errors.add('${slot.date.toString().split(' ')[0]}: ${e.toString()}');
        }
      }

      debugPrint('[ScheduleService] 📊 Результат: $successCount забронировано');

      notifyListeners();

      return {
        'groupId': groupId,
        'totalBooked': successCount,
        'errors': errors,
      };
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Критическая ошибка постоянного расписания: $e');
      rethrow;
    }
  }

  Future<int> cancelRecurringGroup(String recurringGroupId) async {
    try {
      debugPrint('[ScheduleService] 🗑️ Отмена группы: $recurringGroupId');

      final result = await _pb.collection('slots').getList(
        filter: 'recurringGroupId="$recurringGroupId"',
        perPage: 500,
      );

      int cancelledCount = 0;

      for (final record in result.items) {
        try {
          await _pb.collection('slots').update(
            record.id,
            body: {
              'isBooked': false,
              'studentId': null,
              'bookingStatus': 'free',
              'isRecurring': false,
              'recurringGroupId': null,
            },
          );
          cancelledCount++;
        } catch (e) {
          debugPrint('[ScheduleService] ❌ Ошибка отмены слота ${record.id}: $e');
        }
      }

      debugPrint('[ScheduleService] ✅ Отменено $cancelledCount слотов');
      notifyListeners();

      return cancelledCount;
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка отмены группы: $e');
      rethrow;
    }
  }

  Future<int> approveRecurringGroup(String recurringGroupId) async {
    try {
      debugPrint('[ScheduleService] ✅ Подтверждение группы: $recurringGroupId');

      final result = await _pb.collection('slots').getList(
        filter: 'recurringGroupId="$recurringGroupId" && bookingStatus="pending"',
        perPage: 500,
      );

      int approvedCount = 0;

      for (final record in result.items) {
        try {
          await _pb.collection('slots').update(
            record.id,
            body: {
              'bookingStatus': 'confirmed',
            },
          );
          approvedCount++;
        } catch (e) {
          debugPrint('[ScheduleService] ❌ Ошибка подтверждения слота ${record.id}: $e');
        }
      }

      debugPrint('[ScheduleService] ✅ Подтверждено $approvedCount слотов');
      notifyListeners();

      return approvedCount;
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка подтверждения группы: $e');
      rethrow;
    }
  }

  Future<int> rejectRecurringGroup(String recurringGroupId) async {
    try {
      debugPrint('[ScheduleService] ❌ Отклонение группы: $recurringGroupId');

      final result = await _pb.collection('slots').getList(
        filter: 'recurringGroupId="$recurringGroupId" && bookingStatus="pending"',
        perPage: 500,
      );

      int rejectedCount = 0;

      for (final record in result.items) {
        try {
          await _pb.collection('slots').update(
            record.id,
            body: {
              'isBooked': false,
              'studentId': null,
              'bookingStatus': 'free',
              'isRecurring': false,
              'recurringGroupId': null,
            },
          );
          rejectedCount++;
        } catch (e) {
          debugPrint('[ScheduleService] ❌ Ошибка отклонения слота ${record.id}: $e');
        }
      }

      debugPrint('[ScheduleService] ✅ Отклонено $rejectedCount слотов');
      notifyListeners();

      return rejectedCount;
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка отклонения группы: $e');
      rethrow;
    }
  }

  Future<List<ScheduleSlot>> getPendingRequests(String tutorId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId" && bookingStatus="pending"',
            sort: '+date,+startTime',
            perPage: 500,
          );

      debugPrint('[ScheduleService] Запросов на бронирование: ${result.totalItems}');

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения запросов: $e');
      return [];
    }
  }

  Future<List<ScheduleSlot>> getStudentRequests(String studentId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'studentId="$studentId" && (bookingStatus="pending" || bookingStatus="confirmed")',
            sort: '+date,+startTime',
            perPage: 500,
          );

      debugPrint('[ScheduleService] Запросов ученика: ${result.totalItems}');

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения запросов ученика: $e');
      return [];
    }
  }

  Future<int> getStudentPendingCount(String studentId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'studentId="$studentId" && bookingStatus="pending"',
            perPage: 1,
          );

      return result.totalItems;
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения количества pending: $e');
      return 0;
    }
  }

  Stream<int> getPendingRequestsCountStream(String tutorId) async* {
    try {
      debugPrint('[ScheduleService] 🔔 Подписка на pending запросы репетитора: $tutorId');

      int currentCount = await _getCount('tutorId="$tutorId" && bookingStatus="pending"');
      yield currentCount;

      final controller = StreamController<int>();

      final unsubscribe = await _pb.collection('slots').subscribe(
        '*',
        (e) async {
          debugPrint('[ScheduleService] 🔔 Событие: ${e.action} для слота ${e.record?.id}');

          if (e.record != null) {
            final slotTutorId = e.record!.data['tutorId'] as String?;
            final bookingStatus = e.record!.data['bookingStatus'] as String?;

            debugPrint('[ScheduleService]   - tutorId: $slotTutorId (нужен: $tutorId)');
            debugPrint('[ScheduleService]   - bookingStatus: $bookingStatus');

            if (slotTutorId == tutorId) {
              final count = await _getCount('tutorId="$tutorId" && bookingStatus="pending"');
              debugPrint('[ScheduleService] 🔔 Новый счётчик: $count');
              controller.add(count);
            }
          }
        },
      );

      yield* controller.stream;

      await unsubscribe();
      await controller.close();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка подписки на pending (tutor): $e');
      yield 0;
    }
  }

  Stream<int> getStudentPendingCountStream(String studentId) async* {
    try {
      debugPrint('[ScheduleService] 🔔 Подписка на pending запросы ученика: $studentId');

      int currentCount = await _getCount('studentId="$studentId" && bookingStatus="pending"');
      yield currentCount;

      final controller = StreamController<int>();

      final unsubscribe = await _pb.collection('slots').subscribe(
        '*',
        (e) async {
          debugPrint('[ScheduleService] 🔔 Событие: ${e.action} для слота ${e.record?.id}');

          if (e.record != null) {
            final slotStudentId = e.record!.data['studentId'] as String?;
            final bookingStatus = e.record!.data['bookingStatus'] as String?;

            debugPrint('[ScheduleService]   - studentId: $slotStudentId (нужен: $studentId)');
            debugPrint('[ScheduleService]   - bookingStatus: $bookingStatus');

            if (slotStudentId == studentId) {
              final count = await _getCount('studentId="$studentId" && bookingStatus="pending"');
              debugPrint('[ScheduleService] 🔔 Новый счётчик: $count');
              controller.add(count);
            }
          }
        },
      );

      yield* controller.stream;

      await unsubscribe();
      await controller.close();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка подписки на pending (student): $e');
      yield 0;
    }
  }

  Future<int> _getCount(String filter) async {
    try {
      final result = await _pb.collection('slots').getList(
        filter: filter,
        perPage: 1,
      );
      return result.totalItems;
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка подсчёта: $e');
      return 0;
    }
  }

  Future<void> unsubscribeFromSlots() async {
    try {
      await _pb.collection('slots').unsubscribe();
      debugPrint('[ScheduleService] ✅ Отписались от slots subscriptions');
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка отписки: $e');
    }
  }

  Future<void> approveBooking(String slotId) async {
    try {
      debugPrint('[ScheduleService] 🟢 Подтверждение запроса на слот: $slotId');

      await _pb.collection('slots').update(
        slotId,
        body: {
          'bookingStatus': 'confirmed',
        },
      );

      debugPrint('[ScheduleService] ✅ Запрос подтверждён: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка подтверждения запроса: $e');
      rethrow;
    }
  }

  Future<void> rejectBooking(String slotId) async {
    try {
      debugPrint('[ScheduleService] 🔴 Отклонение запроса на слот: $slotId');

      await _pb.collection('slots').update(
        slotId,
        body: {
          'bookingStatus': 'free',
          'isBooked': false,
          'studentId': null,
        },
      );

      debugPrint('[ScheduleService] ✅ Запрос отклонён, слот освобождён: $slotId');
      notifyListeners();
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Ошибка отклонения запроса: $e');
      rethrow;
    }
  }

  Future<List<ScheduleSlot>> getAvailableSlots(String tutorId) async {
    try {
      final result = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId" && isBooked=false',
            sort: '+date,+startTime',
            perPage: 500,
          );

      debugPrint('[ScheduleService] Доступных слотов: ${result.totalItems}');

      return result.items.map((record) => ScheduleSlot.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('[ScheduleService] Ошибка получения доступных слотов: $e');
      return [];
    }
  }

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

  Future<int> generateSlotsFromTemplate({
    required String tutorId,
    int daysAhead = 28,
  }) async {
    int createdCount = 0;

    try {
      debugPrint('[ScheduleService] 🔄 Начало генерации слотов на $daysAhead дней');

      final templatesResult = await _pb.collection('weekly_templates').getList(
            filter: 'tutorId="$tutorId" && isActive=true',
            perPage: 500,
          );

      if (templatesResult.items.isEmpty) {
        debugPrint('[ScheduleService] ⚠️ Шаблон не настроен');
        return 0;
      }

      debugPrint('[ScheduleService] ✅ Загружено ${templatesResult.items.length} шаблонов');

      Map<int, List<WeeklyTemplate>> templatesByDay = {};
      for (var record in templatesResult.items) {
        final template = WeeklyTemplate.fromRecord(record);
        final day = template.dayOfWeek;
        templatesByDay[day] = templatesByDay[day] ?? [];
        templatesByDay[day]!.add(template);
      }

      final today = DateTime.now();

      for (int i = 0; i <= daysAhead; i++) {
        final date = today.add(Duration(days: i));
        final dateOnly = DateTime(date.year, date.month, date.day);
        final dayOfWeek = date.weekday;

        if (!templatesByDay.containsKey(dayOfWeek)) continue;

        for (var template in templatesByDay[dayOfWeek]!) {
          final dateStr = _formatDate(dateOnly);
          final existing = await _pb.collection('slots').getList(
                filter:
                    'tutorId="$tutorId" && date="$dateStr" && startTime="${template.startTime}" && endTime="${template.endTime}"',
                perPage: 1,
              );

          if (existing.items.isEmpty) {
            await _pb.collection('slots').create(body: {
              'tutorId': tutorId,
              'date': dateStr,
              'startTime': template.startTime,
              'endTime': template.endTime,
              'isBooked': false,
              'isPaid': false,
              'bookingStatus': 'free',
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

  Future<bool> checkAndGenerateSlots(
    String tutorId, {
    int minDaysAhead = 14,
    int daysToGenerate = 28,
  }) async {
    try {
      debugPrint('[ScheduleService] 🔍 Проверка необходимости генерации слотов');

      final farthestSlotResult = await _pb.collection('slots').getList(
            filter: 'tutorId="$tutorId"',
            sort: '-date',
            perPage: 1,
          );

      if (farthestSlotResult.items.isEmpty) {
        debugPrint('[ScheduleService] ⚠️ Слотов нет, генерируем на $daysToGenerate дней');
        await generateSlotsFromTemplate(
            tutorId: tutorId, daysAhead: daysToGenerate);
        return true;
      }

      final farthestDate = DateTime.parse(farthestSlotResult.items.first.data['date']);
      final today = DateTime.now();
      final daysAhead = farthestDate.difference(today).inDays;

      debugPrint('[ScheduleService] 📊 Слоты есть на $daysAhead дней вперед');

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

  Future<int> clearGeneratedFreeSlots(String tutorId) async {
    int deletedCount = 0;

    try {
      debugPrint('[ScheduleService] 🗑️ Очистка сгенерированных свободных слотов');

      final today = DateTime.now();
      final todayStr = _formatDate(today);

      final result = await _pb.collection('slots').getList(
            filter:
                'tutorId="$tutorId" && generatedFromTemplate=true && isBooked=false && date>="$todayStr"',
            perPage: 500,
          );

      debugPrint('[ScheduleService] 🔍 Найдено ${result.items.length} слотов для удаления');

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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
