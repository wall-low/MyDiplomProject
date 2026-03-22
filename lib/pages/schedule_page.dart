import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import '../components/user_avatar.dart';
import '../components/payment_dialog.dart';
import '../components/review_dialog.dart';
import '../models/schedule_slot.dart';
import '../service/auth.dart';
import '../service/databases.dart';
import '../service/schedule_service.dart';
import '../service/review_service.dart';
import '../service/tutor_profile_service.dart';
import 'weekly_template_setup_page.dart';
import 'chat_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with SingleTickerProviderStateMixin {
  final ScheduleService _scheduleService = ScheduleService();
  final Auth _auth = Auth();
  final Databases _db = Databases();
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now(); // Для календаря ученика
  bool _isTutor = false;
  bool _isLoading = true;
  String? _loadError;
  late AnimationController _refreshController;

  // Формат календаря (для ученика)
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Отслеживание перевернутых карточек
  final Set<String> _flippedCards = {};

  // Все занятия ученика (для календаря)
  List<ScheduleSlot> _allStudentSlots = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru', null);
    // Инициализируем контроллер анимации для кнопки обновления
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadUserRole();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await _db.getUserFromPocketBase(_auth.getCurrentUid());
      final isTutor = user?.role == 'Репетитор';

      // Для ученика загружаем все занятия сразу (для календаря)
      if (!isTutor) {
        _allStudentSlots = await _scheduleService.getStudentSlots(_auth.getCurrentUid());
      }

      if (mounted) {
        setState(() {
          _isTutor = isTutor;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Не удалось загрузить расписание';
        });
      }
    }
  }

  /// Обновить расписание вручную
  ///
  /// Запускает анимацию вращения кнопки и обновляет список слотов через setState()
  Future<void> _refreshSchedule() async {
    // Запускаем анимацию вращения
    _refreshController.forward(from: 0.0);

    debugPrint('[SchedulePage] 🔄 Ручное обновление расписания');

    // Для ученика перезагружаем все занятия
    if (!_isTutor) {
      try {
        _allStudentSlots = await _scheduleService.getStudentSlots(_auth.getCurrentUid());
      } catch (e) {
        debugPrint('[SchedulePage] ❌ Ошибка обновления занятий: $e');
      }
    }

    // Обновляем UI
    if (mounted) {
      setState(() {});

      // Показываем уведомление
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Расписание обновлено'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Получить занятия на конкретную дату (для календаря ученика)
  List<ScheduleSlot> _getEventsForDay(DateTime day) {
    return _allStudentSlots.where((slot) {
      return isSameDay(slot.date, day);
    }).toList();
  }

  /// Проверить, можно ли отменить занятие (до занятия > 24 часа)
  bool _canCancelSlot(ScheduleSlot slot) {
    try {
      final now = DateTime.now();
      final slotDateTime = DateTime(
        slot.date.year,
        slot.date.month,
        slot.date.day,
        int.parse(slot.startTime.split(':')[0]),
        int.parse(slot.startTime.split(':')[1]),
      );

      final difference = slotDateTime.difference(now);
      return difference.inHours >= 24;
    } catch (e) {
      debugPrint('[SchedulePage] ❌ Ошибка проверки времени отмены: $e');
      return false;
    }
  }

  /// Получить цвет для карточки слота (с учетом роли пользователя)
  /// Проверка: занятие прошло >2 часа назад и не оплачено (для ученика)
  bool _isUnpaidOverdue(ScheduleSlot slot) {
    if (_isTutor) return false;
    if (!slot.isBooked) return false;
    if (slot.isPaid) return false;
    final slotEnd = DateTime(
      slot.date.year, slot.date.month, slot.date.day,
      int.parse(slot.endTime.split(':')[0]),
      int.parse(slot.endTime.split(':')[1]),
    );
    return DateTime.now().difference(slotEnd).inHours >= 2;
  }

  Color _getSlotColor(ScheduleSlot slot, ColorScheme colorScheme) {
    if (_isTutor) {
      // Репетитор: красный = забронировано, зеленый = свободно, серый = прошло
      if (slot.isBooked) return Colors.red;
      if (slot.isPast) return Colors.grey;
      return Colors.green;
    } else {
      // Ученик: красный = не оплачено >2ч, синий = будущее, серый = прошедшее/оплачено
      if (_isUnpaidOverdue(slot)) return Colors.red;
      if (slot.isPast) return Colors.grey;
      return colorScheme.primary;
    }
  }

  /// Получить текст статуса слота
  String _getSlotStatusText(ScheduleSlot slot) {
    if (_isTutor) {
      if (slot.isBooked) return 'Забронировано';
      if (slot.isPast) return 'Прошло';
      return 'Свободно';
    } else {
      if (_isUnpaidOverdue(slot)) return 'Не оплачено';
      if (slot.isPast) return 'Завершено';
      return 'Предстоит';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadUserRole();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _isTutor ? 'М О Е   Р А С П И С А Н И Е' : 'М О И   З А Н Я Т И Я',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          // Кнопка переключения вида календаря (только для учеников)
          if (!_isTutor)
            IconButton(
              icon: Icon(
                _calendarFormat == CalendarFormat.month
                    ? Icons.calendar_view_week
                    : Icons.calendar_view_month,
              ),
              tooltip: _calendarFormat == CalendarFormat.month
                  ? 'Неделя'
                  : 'Месяц',
              onPressed: () {
                setState(() {
                  _calendarFormat = _calendarFormat == CalendarFormat.month
                      ? CalendarFormat.week
                      : CalendarFormat.month;
                });
              },
            ),
          // Кнопка обновления (для всех пользователей)
          RotationTransition(
            turns: _refreshController,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Обновить',
              onPressed: _refreshSchedule,
            ),
          ),
          // Кнопка настройки недельного графика (только для репетиторов)
          if (_isTutor)
            IconButton(
              icon: const Icon(Icons.event_repeat),
              tooltip: 'Недельный график',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WeeklyTemplateSetupPage(),
                  ),
                );

                // Если шаблон был применён, обновляем список слотов
                if (result == true && mounted) {
                  setState(() {});
                }
              },
            ),
        ],
      ),
      body: _isTutor
          ? Column(
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
            )
          : _buildStudentView(colorScheme),
      floatingActionButton: _isTutor
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSlotDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Добавить слот'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            )
          : null,
    );
  }

  Widget _buildDateSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colorScheme.primary),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Flexible(
            child: InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateFormat('d MMMM, EEEE', 'ru').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  /// Представление для ученика с сворачивающимся календарем
  Widget _buildStudentView(ColorScheme colorScheme) {
    final slotsForSelectedDate = _getEventsForDay(_selectedDate);

    return Column(
      children: [
        // Календарь (сворачивается автоматически при скролле)
        _buildCalendar(colorScheme),
        // Список занятий
        Expanded(
          child: slotsForSelectedDate.isEmpty
              ? Center(
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
                        'Нет занятий на эту дату',
                        style: TextStyle(
                          color: colorScheme.secondary,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Выберите другую дату в календаре',
                        style: TextStyle(
                          color: colorScheme.secondary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: slotsForSelectedDate.length,
                  itemBuilder: (context, index) {
                    final slot = slotsForSelectedDate[index];
                    return _buildSlotCard(slot, colorScheme);
                  },
                ),
        ),
      ],
    );
  }

  /// Календарь для ученика с маркерами дат
  Widget _buildCalendar(ColorScheme colorScheme) {
    return Material(
        color: colorScheme.surface,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: TableCalendar<ScheduleSlot>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            locale: 'ru',
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Месяц',
              CalendarFormat.week: 'Неделя',
            },
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            calendarStyle: CalendarStyle(
          // Сегодняшняя дата
          todayDecoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          // Выбранная дата
          selectedDecoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          // Маркеры событий (точки под датой)
          markerDecoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          // Обычные даты
          defaultTextStyle: TextStyle(color: colorScheme.onSurface),
          weekendTextStyle: TextStyle(color: colorScheme.error),
          outsideTextStyle: TextStyle(color: colorScheme.secondary.withValues(alpha: 0.5)),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.primary),
          rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.primary),
          // Небольшой декоративный элемент внизу header'а для подсказки
          headerMargin: const EdgeInsets.only(bottom: 4),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
          ),
        ),
    );
  }

  Widget _buildScheduleList(ColorScheme colorScheme) {
    // Этот метод используется только для репетиторов
    // Для учеников используется _buildStudentView с CustomScrollView
    return FutureBuilder<List<ScheduleSlot>>(
      key: ValueKey('tutor_${_selectedDate.toString()}'),
      future: _scheduleService.getTutorScheduleByDate(
        _auth.getCurrentUid(),
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
                  'Нет записей на эту дату',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Добавьте новый слот',
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

  Widget _buildSlotCard(ScheduleSlot slot, ColorScheme colorScheme) {
    final isFlipped = _flippedCards.contains(slot.id);

    return GestureDetector(
      onTap: () {
        // Переворачиваем карточку только если она забронирована
        if (slot.isBooked && slot.studentId != null) {
          setState(() {
            if (isFlipped) {
              _flippedCards.remove(slot.id);
            } else {
              _flippedCards.add(slot.id);
            }
          });
        } else if (!slot.isBooked && !slot.isPast) {
          // Для свободных слотов показываем опции
          _showSlotOptions(slot);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            child: child,
            builder: (context, child) {
              final isUnder = (ValueKey(isFlipped) != child!.key);
              var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
              tilt *= isUnder ? -1.0 : 1.0;
              final value = isUnder ? min(rotateAnim.value, pi / 2) : rotateAnim.value;
              return Transform(
                transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: isFlipped
            ? _buildFlippedCard(slot, colorScheme)
            : _buildFrontCard(slot, colorScheme),
      ),
    );
  }

  /// Передняя сторона карточки (время + статус)
  Widget _buildFrontCard(ScheduleSlot slot, ColorScheme colorScheme) {
    final slotColor = _getSlotColor(slot, colorScheme);
    final unpaidOverdue = _isUnpaidOverdue(slot);

    return Card(
      key: const ValueKey(false),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: unpaidOverdue
          ? Colors.red.withValues(alpha: 0.07)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: slotColor.withValues(alpha: unpaidOverdue ? 0.5 : 0.2),
          width: unpaidOverdue ? 1.5 : 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Цветная полоска слева
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: slotColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Основной контент
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Время
                      Row(
                        children: [
                          Text(
                            slot.startTime,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '—',
                              style: TextStyle(
                                fontSize: 24,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          Text(
                            slot.endTime,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      if (slot.subject != null && slot.subject!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          slot.subject!,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Статус
                      Row(
                        children: [
                          Container(
                            height: 8,
                            width: 8,
                            decoration: BoxDecoration(
                              color: slotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getSlotStatusText(slot).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (slot.isBooked && slot.studentId != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              height: 20,
                              width: 1,
                              color: colorScheme.outlineVariant,
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      // Предупреждение для ученика: не оплачено >2ч
                      if (unpaidOverdue) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Вы не оплатили занятие — оплатите его',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Кнопка действия справа
              if (_isTutor && !slot.isBooked && !slot.isPast)
                _buildActionButton(
                  icon: Icons.close,
                  color: colorScheme.error,
                  onPressed: () => _deleteSlot(slot.id),
                  tooltip: 'Удалить',
                )
              else if (!_isTutor && slot.isBooked && !slot.isPast)
                _buildActionButton(
                  icon: Icons.close,
                  color: _canCancelSlot(slot)
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  onPressed: _canCancelSlot(slot)
                      ? () => _cancelBooking(slot)
                      : null,
                  tooltip: _canCancelSlot(slot)
                      ? 'Отменить'
                      : 'Нельзя отменить',
                )
              else if (!_isTutor && slot.isBooked && slot.isPast && !slot.isPaid)
                _buildActionButton(
                  icon: Icons.payment,
                  color: Colors.green,
                  onPressed: () => _showPaymentDialog(slot),
                  tooltip: 'Оплатить',
                )
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
    );
  }

  /// Кнопка действия (удалить/отменить)
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// Обратная сторона карточки (информация об ученике/репетиторе)
  Widget _buildFlippedCard(ScheduleSlot slot, ColorScheme colorScheme) {
    // Определяем чей профиль показывать:
    // - Репетитор видит ученика (studentId)
    // - Ученик видит репетитора (tutorId)
    final otherUserId = _isTutor ? slot.studentId! : slot.tutorId;
    final roleLabel = _isTutor ? 'Ученик' : 'Репетитор';

    return Card(
      key: const ValueKey(true),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 170, // Та же высота, что и передняя карточка
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder(
            future: _db.getUserFromPocketBase(otherUserId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                );
              }

              final otherUser = snapshot.data!;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      // Аватар
                      UserAvatar(
                        avatarUrl: otherUser.avatarUrl,
                        size: 56,
                      ),
                      const SizedBox(width: 16),
                      // Информация о пользователе
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roleLabel,
                              style: TextStyle(
                                color: colorScheme.secondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              otherUser.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              otherUser.city,
                              style: TextStyle(
                                color: colorScheme.secondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Кнопка "Написать"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              receiverName: otherUser.name,
                              receiverID: otherUserId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Написать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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

  void _showSlotOptions(ScheduleSlot slot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Удалить слот'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSlot(slot.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSlotDialog(BuildContext context) async {
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Добавить слот'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Начало'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                      child: Text(startTime.format(context)),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Конец'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                      child: Text(endTime.format(context)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _addSlot(startTime, endTime);
                  },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addSlot(TimeOfDay startTime, TimeOfDay endTime) async {
    try {
      final start = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final end = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      debugPrint('[SchedulePage] 📝 Создание слота: ${_selectedDate.toString().split(' ')[0]} $start-$end');
      debugPrint('[SchedulePage] 👤 TutorID: ${_auth.getCurrentUid()}');

      await _scheduleService.addSlot(
        tutorId: _auth.getCurrentUid(),
        date: _selectedDate,
        startTime: start,
        endTime: end,
      );

      debugPrint('[SchedulePage] ✅ Слот создан успешно');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Слот добавлен'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Обновляем список слотов
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('[SchedulePage] ❌ Ошибка добавления слота: $e');
      debugPrint('[SchedulePage] 📋 StackTrace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteSlot(String slotId) async {
    try {
      await _scheduleService.deleteSlot(slotId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Слот удален'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка удаления слота'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Отменить бронирование занятия (для ученика)
  Future<void> _cancelBooking(ScheduleSlot slot) async {
    // Показываем диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена занятия'),
        content: Text(
          'Вы уверены, что хотите отменить занятие ${slot.startTime} - ${slot.endTime}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _scheduleService.cancelBooking(slot.id);

      // Обновляем список занятий ученика
      _allStudentSlots = await _scheduleService.getStudentSlots(_auth.getCurrentUid());

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Занятие отменено'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Показать диалог оплаты занятия
  ///
  /// Вызывается для учеников после прошедшего неоплаченного занятия
  Future<void> _showPaymentDialog(ScheduleSlot slot) async {
    try {
      // Получаем информацию о репетиторе
      final tutorUser = await _db.getUserFromPocketBase(slot.tutorId);
      if (tutorUser == null) {
        throw Exception('Не удалось загрузить данные репетитора');
      }

      // Рассчитываем сумму: цена за час × длительность слота
      double amount = 0;
      try {
        final tutorProfileService = TutorProfileService();
        final tutorProfile = await tutorProfileService.getTutorProfileByUserId(slot.tutorId);

        if (tutorProfile != null) {
          // Вычисляем длительность слота в часах
          final startParts = slot.startTime.split(':');
          final endParts = slot.endTime.split(':');
          final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          final durationHours = (endMinutes - startMinutes) / 60.0;

          // Берём цену за предмет слота
          double? hourlyRate;
          if (slot.subject != null && tutorProfile.subjectPrices.containsKey(slot.subject)) {
            hourlyRate = tutorProfile.subjectPrices[slot.subject!];
          } else if (tutorProfile.subjectPrices.isNotEmpty) {
            hourlyRate = tutorProfile.subjectPrices.values.first;
          } else if (tutorProfile.priceMin != null) {
            hourlyRate = tutorProfile.priceMin;
          }

          if (hourlyRate != null) {
            amount = hourlyRate * durationHours;
          }
        }
      } catch (e) {
        debugPrint('[SchedulePage] ⚠️ Не удалось рассчитать стоимость: $e');
      }

      if (!mounted) return;

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PaymentDialog(
          slot: slot,
          tutorId: slot.tutorId,
          tutorName: tutorUser.name,
          amount: amount,
        ),
      );

      // Показываем диалог отзыва (если ещё не оставляли)
      if (result != null && mounted) {
        final isVerified = result == 'app';
        final reviewService = ReviewService();
        final alreadyReviewed = await reviewService.hasReviewForLesson(
          _auth.getCurrentUid(),
          slot.id,
        );

        if (!alreadyReviewed && mounted) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => ReviewDialog(
              slot: slot,
              tutorId: slot.tutorId,
              studentId: _auth.getCurrentUid(),
              tutorName: tutorUser.name,
              isVerified: isVerified,
            ),
          );
        }
      }

      // ВСЕГДА обновляем список после закрытия диалога
      if (mounted) {
        _allStudentSlots = await _scheduleService.getStudentSlots(_auth.getCurrentUid());
        setState(() {});
      }
    } catch (e) {
      debugPrint('[SchedulePage] ❌ Ошибка открытия диалога оплаты: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
