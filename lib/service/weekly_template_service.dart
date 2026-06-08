import 'package:flutter/foundation.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:p7/models/weekly_template.dart';

class WeeklyTemplateService extends ChangeNotifier {
  final _pb = PocketBaseService().client;

  Future<List<WeeklyTemplate>> getTutorTemplates(String tutorId) async {
    try {
      final result = await _pb.collection('weekly_templates').getList(
            filter: 'tutorId="$tutorId"',
            sort: 'dayOfWeek,startTime',
            perPage: 500,
          );

      debugPrint(
          '[WeeklyTemplateService] Загружено ${result.items.length} шаблонов');

      return result.items.map((r) => WeeklyTemplate.fromRecord(r)).toList();
    } catch (e, stackTrace) {
      debugPrint('[WeeklyTemplateService] Ошибка загрузки шаблонов:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');
      return [];
    }
  }

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
      debugPrint(
          '[WeeklyTemplateService] Ошибка загрузки шаблонов для дня $dayOfWeek: $e');
      return [];
    }
  }

  Future<WeeklyTemplate?> createTemplate(WeeklyTemplate template) async {
    try {
      final existing = await getTemplatesForDay(
          template.tutorId, template.dayOfWeek);

      for (var existingTemplate in existing) {
        if (_timeOverlaps(template.startTime, template.endTime,
            existingTemplate.startTime, existingTemplate.endTime)) {
          throw Exception(
              'Слот пересекается с существующим ${existingTemplate.startTime}-${existingTemplate.endTime}');
        }
      }

      final record = await _pb.collection('weekly_templates').create(
            body: template.toMap(),
          );

      debugPrint('[WeeklyTemplateService] Шаблон создан: ${template.getFullDisplay()}');

      notifyListeners();
      return WeeklyTemplate.fromRecord(record);
    } catch (e, stackTrace) {
      debugPrint('[WeeklyTemplateService] Ошибка создания шаблона:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');
      return null;
    }
  }

  Future<WeeklyTemplate?> updateTemplate(
      String templateId, WeeklyTemplate updatedTemplate) async {
    try {
      final record = await _pb.collection('weekly_templates').update(
            templateId,
            body: updatedTemplate.toMap(),
          );

      debugPrint('[WeeklyTemplateService] Шаблон обновлен: $templateId');

      notifyListeners();
      return WeeklyTemplate.fromRecord(record);
    } catch (e) {
      debugPrint('[WeeklyTemplateService] Ошибка обновления шаблона: $e');
      return null;
    }
  }

  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _pb.collection('weekly_templates').delete(templateId);

      debugPrint('[WeeklyTemplateService] Шаблон удален: $templateId');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[WeeklyTemplateService] Ошибка удаления шаблона: $e');
      return false;
    }
  }

  Future<void> clearAllTemplates(String tutorId) async {
    try {
      final templates = await getTutorTemplates(tutorId);

      for (var template in templates) {
        await deleteTemplate(template.id);
      }

      debugPrint('[WeeklyTemplateService] Все шаблоны очищены');
    } catch (e) {
      debugPrint('[WeeklyTemplateService] Ошибка очистки шаблонов: $e');
    }
  }

  Future<void> clearDayTemplates(String tutorId, int dayOfWeek) async {
    try {
      final templates = await getTemplatesForDay(tutorId, dayOfWeek);

      for (var template in templates) {
        await deleteTemplate(template.id);
      }

      debugPrint(
          '[WeeklyTemplateService] Шаблоны дня $dayOfWeek очищены');
    } catch (e) {
      debugPrint('[WeeklyTemplateService] Ошибка очистки дня: $e');
    }
  }

  Future<bool> copyMondayToWeekdays(String tutorId) async {
    try {
      final mondayTemplates = await getTemplatesForDay(tutorId, 1);

      if (mondayTemplates.isEmpty) {
        debugPrint('[WeeklyTemplateService] Понедельник пустой, нечего копировать');
        return false;
      }

      debugPrint(
          '[WeeklyTemplateService] Копируем ${mondayTemplates.length} слотов понедельника на Вт-Пт');

      for (int day = 2; day <= 5; day++) {
        await clearDayTemplates(tutorId, day);

        for (var mondayTemplate in mondayTemplates) {
          await _pb.collection('weekly_templates').create(body: {
            'tutorId': tutorId,
            'dayOfWeek': day,
            'startTime': mondayTemplate.startTime,
            'endTime': mondayTemplate.endTime,
            'isActive': true,
          });
        }

        debugPrint('[WeeklyTemplateService] День $day скопирован');
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('[WeeklyTemplateService] Ошибка копирования:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');
      return false;
    }
  }

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

  bool _timeOverlaps(String start1, String end1, String start2, String end2) {

    return !(end1.compareTo(start2) <= 0 || start1.compareTo(end2) >= 0);
  }

  bool isValidTimeFormat(String time) {
    final regex = RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$');
    return regex.hasMatch(time);
  }

  bool isValidTimeRange(String startTime, String endTime) {
    return endTime.compareTo(startTime) > 0;
  }
}
