import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:p7/models/weekly_template.dart';

/// Сервис для управления недельным шаблоном расписания репетитора
///
/// Предоставляет методы для CRUD операций с шаблонами
/// и утилиты (копирование понедельника на все будни, очистка)
class WeeklyTemplateService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  /// Получить все шаблоны репетитора
  ///
  /// Возвращает список WeeklyTemplate, отсортированный по дню недели и времени начала
  Future<List<WeeklyTemplate>> getTutorTemplates(String tutorId) async {
    try {
      final result = await _pb.collection('weekly_templates').getList(
            filter: 'tutorId="$tutorId"',
            sort: 'dayOfWeek,startTime',
            perPage: 500,
          );

      print(
          '[WeeklyTemplateService] ✅ Загружено ${result.items.length} шаблонов');

      return result.items.map((r) => WeeklyTemplate.fromRecord(r)).toList();
    } catch (e, stackTrace) {
      print('[WeeklyTemplateService] ❌ Ошибка загрузки шаблонов:');
      print('  Error: $e');
      print('  StackTrace: $stackTrace');
      return [];
    }
  }

  /// Получить шаблоны для конкретного дня недели
  ///
  /// dayOfWeek: 1-7 (1=Пн, 7=Вс)
  Future<List<WeeklyTemplate>> getTemplatesForDay(
      String tutorId, int dayOfWeek) async {
    try {
      final result = await _pb.collection('weekly_templates').getList(
            filter: 'tutorId="$tutorId" && dayOfWeek=$dayOfWeek',
            sort: 'startTime',
            perPage: 100,
          );

      return result.items.map((r) => WeeklyTemplate.fromRecord(r)).toList();
    } catch (e) {
      print(
          '[WeeklyTemplateService] ❌ Ошибка загрузки шаблонов для дня $dayOfWeek: $e');
      return [];
    }
  }

  /// Создать новый шаблон
  ///
  /// Валидирует, что нет пересечений с существующими слотами в этот день
  Future<WeeklyTemplate?> createTemplate(WeeklyTemplate template) async {
    try {
      // Проверяем пересечения
      final existing = await getTemplatesForDay(
          template.tutorId, template.dayOfWeek);

      for (var existingTemplate in existing) {
        if (_timeOverlaps(template.startTime, template.endTime,
            existingTemplate.startTime, existingTemplate.endTime)) {
          throw Exception(
              'Слот пересекается с существующим ${existingTemplate.startTime}-${existingTemplate.endTime}');
        }
      }

      // Создаем
      final record = await _pb.collection('weekly_templates').create(
            body: template.toMap(),
          );

      print('[WeeklyTemplateService] ✅ Шаблон создан: ${template.getFullDisplay()}');

      notifyListeners();
      return WeeklyTemplate.fromRecord(record);
    } catch (e, stackTrace) {
      print('[WeeklyTemplateService] ❌ Ошибка создания шаблона:');
      print('  Error: $e');
      print('  StackTrace: $stackTrace');
      return null;
    }
  }

  /// Обновить существующий шаблон
  Future<WeeklyTemplate?> updateTemplate(
      String templateId, WeeklyTemplate updatedTemplate) async {
    try {
      final record = await _pb.collection('weekly_templates').update(
            templateId,
            body: updatedTemplate.toMap(),
          );

      print('[WeeklyTemplateService] ✅ Шаблон обновлен: $templateId');

      notifyListeners();
      return WeeklyTemplate.fromRecord(record);
    } catch (e) {
      print('[WeeklyTemplateService] ❌ Ошибка обновления шаблона: $e');
      return null;
    }
  }

  /// Удалить шаблон
  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _pb.collection('weekly_templates').delete(templateId);

      print('[WeeklyTemplateService] ✅ Шаблон удален: $templateId');

      notifyListeners();
      return true;
    } catch (e) {
      print('[WeeklyTemplateService] ❌ Ошибка удаления шаблона: $e');
      return false;
    }
  }

  /// Удалить все шаблоны репетитора (для очистки)
  Future<void> clearAllTemplates(String tutorId) async {
    try {
      final templates = await getTutorTemplates(tutorId);

      for (var template in templates) {
        await deleteTemplate(template.id);
      }

      print('[WeeklyTemplateService] ✅ Все шаблоны очищены');
    } catch (e) {
      print('[WeeklyTemplateService] ❌ Ошибка очистки шаблонов: $e');
    }
  }

  /// Удалить все шаблоны для конкретного дня
  Future<void> clearDayTemplates(String tutorId, int dayOfWeek) async {
    try {
      final templates = await getTemplatesForDay(tutorId, dayOfWeek);

      for (var template in templates) {
        await deleteTemplate(template.id);
      }

      print(
          '[WeeklyTemplateService] ✅ Шаблоны дня $dayOfWeek очищены');
    } catch (e) {
      print('[WeeklyTemplateService] ❌ Ошибка очистки дня: $e');
    }
  }

  /// Скопировать шаблоны понедельника на все будни (Вт-Пт)
  ///
  /// Удобная функция для быстрой настройки одинакового расписания
  Future<bool> copyMondayToWeekdays(String tutorId) async {
    try {
      // 1. Получаем все слоты понедельника
      final mondayTemplates = await getTemplatesForDay(tutorId, 1);

      if (mondayTemplates.isEmpty) {
        print('[WeeklyTemplateService] ⚠️ Понедельник пустой, нечего копировать');
        return false;
      }

      print(
          '[WeeklyTemplateService] 🔄 Копируем ${mondayTemplates.length} слотов понедельника на Вт-Пт');

      // 2. Для каждого дня недели (Вт-Пт)
      for (int day = 2; day <= 5; day++) {
        // Удаляем старые шаблоны этого дня
        await clearDayTemplates(tutorId, day);

        // Создаем новые (копии понедельника)
        for (var mondayTemplate in mondayTemplates) {
          await _pb.collection('weekly_templates').create(body: {
            'tutorId': tutorId,
            'dayOfWeek': day,
            'startTime': mondayTemplate.startTime,
            'endTime': mondayTemplate.endTime,
            'isActive': true,
          });
        }

        print('[WeeklyTemplateService] ✅ День $day скопирован');
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      print('[WeeklyTemplateService] ❌ Ошибка копирования:');
      print('  Error: $e');
      print('  StackTrace: $stackTrace');
      return false;
    }
  }

  /// Группировка шаблонов по дням недели
  ///
  /// Возвращает Map: dayOfWeek → List<WeeklyTemplate>
  /// Удобно для отображения в UI
  Future<Map<int, List<WeeklyTemplate>>> getTemplatesGroupedByDay(
      String tutorId) async {
    final templates = await getTutorTemplates(tutorId);

    Map<int, List<WeeklyTemplate>> grouped = {};

    for (var template in templates) {
      final day = template.dayOfWeek;
      grouped[day] = grouped[day] ?? [];
      grouped[day]!.add(template);
    }

    return grouped;
  }

  /// Проверка пересечения временных интервалов
  ///
  /// Возвращает true, если интервалы пересекаются
  bool _timeOverlaps(String start1, String end1, String start2, String end2) {
    // Простая проверка: интервалы НЕ пересекаются, если
    // один заканчивается ДО начала другого
    return !(end1.compareTo(start2) <= 0 || start1.compareTo(end2) >= 0);
  }

  /// Валидация времени (формат HH:mm)
  bool isValidTimeFormat(String time) {
    final regex = RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$');
    return regex.hasMatch(time);
  }

  /// Валидация: endTime > startTime
  bool isValidTimeRange(String startTime, String endTime) {
    return endTime.compareTo(startTime) > 0;
  }
}
