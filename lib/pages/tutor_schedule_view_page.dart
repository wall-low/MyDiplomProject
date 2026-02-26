import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/schedule_slot.dart';
import '../service/auth.dart';
import '../service/schedule_service.dart';

/// Страница просмотра расписания репетитора (для ученика)
///
/// Функции:
/// - Просмотр доступных слотов репетитора
/// - Бронирование свободных слотов
/// - Выбор даты через календарь
class TutorScheduleViewPage extends StatefulWidget {
  final String tutorId;
  final String tutorName;

  const TutorScheduleViewPage({
    super.key,
    required this.tutorId,
    required this.tutorName,
  });

  @override
  State<TutorScheduleViewPage> createState() => _TutorScheduleViewPageState();
}

class _TutorScheduleViewPageState extends State<TutorScheduleViewPage> {
  final ScheduleService _scheduleService = ScheduleService();
  final Auth _auth = Auth();
  DateTime _selectedDate = DateTime.now();
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru', null);
  }

  void _refreshSlots() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Расписание',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              widget.tutorName,
              style: TextStyle(
                color: colorScheme.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.primaryContainer,
          ),
          _buildDateSelector(colorScheme),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.primaryContainer,
          ),
          Expanded(
            child: _buildScheduleList(colorScheme),
          ),
        ],
      ),
    );
  }

  /// Селектор даты с кнопками навигации
  Widget _buildDateSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Кнопка "Назад" (предыдущий день)
          IconButton(
            icon: Icon(Icons.chevron_left, color: colorScheme.primary),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),

          // Кнопка выбора даты из календаря
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('d MMMM, EEEE', 'ru').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка "Вперед" (следующий день)
          IconButton(
            icon: Icon(Icons.chevron_right, color: colorScheme.primary),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  /// Список слотов на выбранную дату
  Widget _buildScheduleList(ColorScheme colorScheme) {
    return FutureBuilder<List<ScheduleSlot>>(
      key: ValueKey('${widget.tutorId}_${_selectedDate.toString()}_$_refreshKey'),
      future: _scheduleService.getTutorScheduleByDate(
        widget.tutorId,
        _selectedDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки',
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        final slots = snapshot.data ?? [];

        if (slots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 80,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'Нет слотов на эту дату',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Попробуйте выбрать другую дату',
                  style: TextStyle(
                    color: colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return _buildSlotCard(slot, colorScheme);
          },
        );
      },
    );
  }

  /// Карточка слота с кнопкой бронирования
  Widget _buildSlotCard(ScheduleSlot slot, ColorScheme colorScheme) {
    // Определяем, забронирован ли слот текущим учеником
    final currentUserId = _auth.getCurrentUid();
    final isMyBooking = slot.isBooked && slot.studentId == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Цветная полоска слева (индикатор статуса)
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: slot.isPast
                    ? Colors.grey
                    : (slot.isBooked
                        ? (isMyBooking ? Colors.blue : Colors.red)
                        : Colors.green),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),

            // Информация о времени
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Время начала и конца
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${slot.startTime} - ${slot.endTime}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Статус слота (бейдж)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: slot.isPast
                          ? Colors.grey.withValues(alpha: 0.1)
                          : (slot.isBooked
                              ? (isMyBooking
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1))
                              : Colors.green.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      slot.isPast
                          ? 'Прошло'
                          : (slot.isBooked
                              ? (isMyBooking
                                  ? 'Вы забронировали'
                                  : 'Забронировано')
                              : 'Свободно'),
                      style: TextStyle(
                        color: slot.isPast
                            ? Colors.grey
                            : (slot.isBooked
                                ? (isMyBooking ? Colors.blue : Colors.red)
                                : Colors.green),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Кнопка действия (Забронировать / Отменить)
            if (!slot.isPast)
              _buildActionButton(slot, isMyBooking, colorScheme),
          ],
        ),
      ),
    );
  }

  /// Кнопка действия (Забронировать или Отменить бронирование)
  Widget _buildActionButton(
      ScheduleSlot slot, bool isMyBooking, ColorScheme colorScheme) {
    if (slot.isBooked) {
      // Если забронирован текущим учеником → кнопка "Отменить"
      if (isMyBooking) {
        return ElevatedButton(
          onPressed: () => _cancelBooking(slot),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Отменить'),
        );
      } else {
        // Если забронирован другим учеником → кнопка неактивна
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Занято'),
        );
      }
    } else {
      // Если свободен → кнопка "Забронировать"
      return ElevatedButton(
        onPressed: () => _bookSlot(slot),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Забронировать'),
      );
    }
  }

  /// Открыть календарь для выбора даты
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ru'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Забронировать слот
  Future<void> _bookSlot(ScheduleSlot slot) async {
    try {
      // Показываем диалог подтверждения
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Подтверждение'),
          content: Text(
            'Забронировать занятие на ${DateFormat('d MMMM', 'ru').format(slot.date)} с ${slot.startTime} до ${slot.endTime}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Забронировать'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Выполняем бронирование
      await _scheduleService.bookSlot(slot.id, _auth.getCurrentUid());

      if (mounted) {
        // Показываем уведомление об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Занятие забронировано'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Мои занятия',
              textColor: Colors.white,
              onPressed: () {
                // Переход на страницу "Мои занятия"
                Navigator.pop(context); // Закрываем текущую страницу
              },
            ),
          ),
        );

        // Обновляем список слотов
        _refreshSlots();
      }
    } catch (e) {
      if (mounted) {
        // Извлекаем понятное сообщение об ошибке
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.replaceAll('Exception: ', '');
        }

        // Показываем диалог с ошибкой и кнопкой обновления
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                const Text('Ошибка бронирования'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 16),
                Text(
                  'Расписание могло измениться. Обновите список слотов.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _refreshSlots();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Отменить бронирование
  Future<void> _cancelBooking(ScheduleSlot slot) async {
    try {
      // Показываем диалог подтверждения
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Отмена бронирования'),
          content: Text(
            'Отменить занятие на ${DateFormat('d MMMM', 'ru').format(slot.date)} с ${slot.startTime} до ${slot.endTime}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Назад'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Отменить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Выполняем отмену бронирования
      await _scheduleService.cancelBooking(slot.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Бронирование отменено'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Обновляем список слотов
        _refreshSlots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка отмены: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
