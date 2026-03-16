import 'package:flutter/material.dart';
import 'package:p7/models/weekly_template.dart';
import 'package:p7/service/weekly_template_service.dart';
import 'package:p7/service/schedule_service.dart';
import 'package:p7/service/auth.dart';

/// Страница настройки недельного шаблона расписания репетитора
///
/// Позволяет:
/// - Настроить рабочие дни и время для каждого дня недели
/// - Скопировать понедельник на все будни
/// - Применить изменения (генерирует слоты на 4 недели вперед)
class WeeklyTemplateSetupPage extends StatefulWidget {
  const WeeklyTemplateSetupPage({super.key});

  @override
  State<WeeklyTemplateSetupPage> createState() =>
      _WeeklyTemplateSetupPageState();
}

class _WeeklyTemplateSetupPageState extends State<WeeklyTemplateSetupPage> {
  final _templateService = WeeklyTemplateService();
  final _scheduleService = ScheduleService();
  final _auth = Auth();

  // Хранилище шаблонов по дням недели
  Map<int, List<WeeklyTemplate>> _templatesByDay = {};

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  /// Загрузка существующих шаблонов
  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);

    try {
      final tutorId = _auth.getCurrentUid();
      if (tutorId.isEmpty) return;

      final templates = await _templateService.getTemplatesGroupedByDay(tutorId);

      setState(() {
        _templatesByDay = templates;
        _isLoading = false;
      });

      debugPrint('[WeeklyTemplateSetup] ✅ Загружено ${templates.length} дней с шаблонами');
    } catch (e) {
      debugPrint('[WeeklyTemplateSetup] ❌ Ошибка загрузки: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Добавить новый временной слот для дня
  Future<void> _addTimeSlot(int dayOfWeek) async {
    final tutorId = _auth.getCurrentUid();
    if (tutorId.isEmpty) return;

    // Показываем диалог выбора времени
    final timeSlot = await _showTimePickerDialog(dayOfWeek);
    if (timeSlot == null) return;

    // Создаем шаблон в БД
    final template = WeeklyTemplate(
      id: '', // Будет создан PocketBase
      tutorId: tutorId,
      dayOfWeek: dayOfWeek,
      startTime: timeSlot['start']!,
      endTime: timeSlot['end']!,
      isActive: true,
    );

    final created = await _templateService.createTemplate(template);

    if (created != null) {
      // Обновляем локальное состояние
      setState(() {
        _templatesByDay[dayOfWeek] = _templatesByDay[dayOfWeek] ?? [];
        _templatesByDay[dayOfWeek]!.add(created);
        // Сортируем по времени начала
        _templatesByDay[dayOfWeek]!.sort((a, b) => a.startTime.compareTo(b.startTime));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Слот добавлен: ${timeSlot['start']} - ${timeSlot['end']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Ошибка: слот пересекается с существующим'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Удалить временной слот
  Future<void> _deleteTimeSlot(int dayOfWeek, WeeklyTemplate template) async {
    // Подтверждение
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить слот?'),
        content: Text('Удалить ${template.getTimeDisplay()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Удаляем из БД
    final success = await _templateService.deleteTemplate(template.id);

    if (success) {
      // Обновляем локальное состояние
      setState(() {
        _templatesByDay[dayOfWeek]?.remove(template);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Слот удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// Скопировать понедельник на все будни
  Future<void> _copyMondayToWeekdays() async {
    final tutorId = _auth.getCurrentUid();
    if (tutorId.isEmpty) return;

    // Проверяем, есть ли слоты в понедельник
    final mondaySlots = _templatesByDay[1] ?? [];
    if (mondaySlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Понедельник пустой, нечего копировать'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Подтверждение
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скопировать понедельник?'),
        content: Text(
          'Скопировать ${mondaySlots.length} слотов понедельника на Вт-Пт?\n\n'
          'Существующие слоты будут заменены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Скопировать'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Показываем загрузку
    setState(() => _isSaving = true);

    // Копируем
    final success = await _templateService.copyMondayToWeekdays(tutorId);

    if (success) {
      // Перезагружаем шаблоны
      await _loadTemplates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Понедельник скопирован на Вт-Пт'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  /// Применить изменения (генерация слотов)
  Future<void> _applyChanges() async {
    final tutorId = _auth.getCurrentUid();
    if (tutorId.isEmpty) return;

    // Подтверждение
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Применить изменения?'),
        content: const Text(
          'Система сгенерирует слоты на 4 недели вперед по вашему шаблону.\n\n'
          'Существующие свободные слоты будут пересозданы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Показываем загрузку
    setState(() => _isSaving = true);

    try {
      // 1. Удаляем старые сгенерированные свободные слоты
      debugPrint('[WeeklyTemplateSetup] 🗑️ Удаление старых слотов...');
      await _scheduleService.clearGeneratedFreeSlots(tutorId);

      // 2. Генерируем новые слоты на 28 дней
      debugPrint('[WeeklyTemplateSetup] 🔄 Генерация новых слотов...');
      final createdCount = await _scheduleService.generateSlotsFromTemplate(
        tutorId: tutorId,
        daysAhead: 28,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Создано $createdCount слотов на 4 недели'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Возвращаемся назад
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[WeeklyTemplateSetup] ❌ Ошибка применения: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Диалог выбора времени начала и конца
  Future<Map<String, String>?> _showTimePickerDialog(int dayOfWeek) async {
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Добавить время (${_getDayName(dayOfWeek)})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Кнопка выбора начала
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(startTime != null
                    ? 'Начало: ${_formatTime(startTime!)}'
                    : 'Выберите время начала'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) {
                    setDialogState(() => startTime = picked);
                  }
                },
              ),

              const SizedBox(height: 8),

              // Кнопка выбора конца
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(endTime != null
                    ? 'Конец: ${_formatTime(endTime!)}'
                    : 'Выберите время окончания'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime ??
                        TimeOfDay(
                          hour: (startTime?.hour ?? 9) + 1,
                          minute: startTime?.minute ?? 0,
                        ),
                  );
                  if (picked != null) {
                    setDialogState(() => endTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: startTime != null && endTime != null
                  ? () {
                      // Валидация
                      final start = _formatTime(startTime!);
                      final end = _formatTime(endTime!);

                      if (end.compareTo(start) <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Время окончания должно быть позже начала'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, {
                        'start': start,
                        'end': end,
                      });
                    }
                  : null,
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Н Е Д Е Л Ь Н Ы Й   Г Р А Ф И К"),
        foregroundColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSaving
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Применяем изменения...'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Кнопка "Скопировать Пн на все будни"
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _copyMondayToWeekdays,
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Скопировать Пн на Вт-Пт'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[50],
                          foregroundColor: Colors.blue[700],
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),

                    // Список дней недели
                    Expanded(
                      child: ListView.builder(
                        itemCount: 7,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          final dayOfWeek = index + 1;
                          return _buildDayCard(dayOfWeek);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _isSaving
          ? null
          : FloatingActionButton.extended(
              onPressed: _applyChanges,
              icon: const Icon(Icons.check),
              label: const Text('Применить изменения'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
    );
  }

  /// Карточка дня недели
  Widget _buildDayCard(int dayOfWeek) {
    final templates = _templatesByDay[dayOfWeek] ?? [];
    final dayName = _getDayName(dayOfWeek);
    final isWeekend = dayOfWeek == 6 || dayOfWeek == 7;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Icon(
          Icons.calendar_today,
          color: isWeekend ? Colors.orange : Colors.blue,
        ),
        title: Text(
          dayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          templates.isEmpty
              ? 'Нет слотов'
              : '${templates.length} ${_getPluralSlots(templates.length)}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        children: [
          // Список слотов
          if (templates.isNotEmpty)
            ...templates.map((template) => ListTile(
                  leading: const Icon(Icons.access_time, size: 20),
                  title: Text(template.getTimeDisplay()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTimeSlot(dayOfWeek, template),
                  ),
                )),

          // Кнопка добавления
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: () => _addTimeSlot(dayOfWeek),
              icon: const Icon(Icons.add),
              label: const Text('Добавить время'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int dayOfWeek) {
    const days = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье'
    ];
    return days[dayOfWeek - 1];
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getPluralSlots(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'слот';
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'слота';
    } else {
      return 'слотов';
    }
  }
}
