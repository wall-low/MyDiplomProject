import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_slot.dart';
import '../service/auth.dart';
import '../service/databases.dart';
import '../service/schedule_service.dart';

class BookingRequestGroup {
  final bool isRecurring;
  final String? recurringGroupId;
  final List<ScheduleSlot> slots;
  final String? studentId;

  BookingRequestGroup({
    required this.isRecurring,
    this.recurringGroupId,
    required this.slots,
    this.studentId,
  });

  ScheduleSlot get firstSlot => slots.first;

  int get count => slots.length;
}

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({super.key});

  @override
  State<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> {
  final ScheduleService _scheduleService = ScheduleService();
  final Auth _auth = Auth();
  final Databases _db = Databases();
  int _refreshKey = 0;

  void _refreshList() {
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
        title: Text(
          'Запросы на бронирование',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
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
          Expanded(
            child: _buildRequestsList(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(ColorScheme colorScheme) {
    return FutureBuilder<List<ScheduleSlot>>(
      key: ValueKey(_refreshKey),
      future: _scheduleService.getPendingRequests(_auth.getCurrentUid()),
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

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'Нет новых запросов',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Когда ученики захотят записаться,\nих запросы появятся здесь',
                  style: TextStyle(
                    color: colorScheme.secondary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final groups = _groupRequests(requests);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _buildGroupCard(group, colorScheme);
          },
        );
      },
    );
  }

  List<BookingRequestGroup> _groupRequests(List<ScheduleSlot> requests) {
    final Map<String, List<ScheduleSlot>> groupsMap = {};
    final List<ScheduleSlot> singleRequests = [];

    for (final request in requests) {
      if (request.isRecurring && request.recurringGroupId != null) {
        if (!groupsMap.containsKey(request.recurringGroupId)) {
          groupsMap[request.recurringGroupId!] = [];
        }
        groupsMap[request.recurringGroupId!]!.add(request);
      } else {
        singleRequests.add(request);
      }
    }

    final List<BookingRequestGroup> result = [];

    groupsMap.forEach((groupId, slots) {
      slots.sort((a, b) => a.date.compareTo(b.date));
      result.add(BookingRequestGroup(
        isRecurring: true,
        recurringGroupId: groupId,
        slots: slots,
        studentId: slots.first.studentId,
      ));
    });

    for (final slot in singleRequests) {
      result.add(BookingRequestGroup(
        isRecurring: false,
        slots: [slot],
        studentId: slot.studentId,
      ));
    }

    result.sort((a, b) => a.firstSlot.date.compareTo(b.firstSlot.date));

    return result;
  }

  Widget _buildGroupCard(BookingRequestGroup group, ColorScheme colorScheme) {
    final request = group.firstSlot;
    final isRecurring = group.isRecurring;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder(
              future: _db.getUserFromPocketBase(request.studentId ?? ''),
              builder: (context, userSnapshot) {
                final userName = userSnapshot.hasData
                    ? userSnapshot.data!.name
                    : 'Загрузка...';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            isRecurring
                                ? 'Постоянное расписание (${group.count} занятий)'
                                : 'Запрос на занятие',
                            style: TextStyle(
                              fontSize: 14,
                              color: isRecurring ? Colors.orange[700] : colorScheme.secondary,
                              fontWeight: isRecurring ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecurring
                    ? Colors.orange.withValues(alpha: 0.1)
                    : colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isRecurring ? Icons.repeat : Icons.calendar_today,
                        size: 20,
                        color: isRecurring ? Colors.orange[700] : colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRecurring
                                  ? 'Каждый ${_getDayName(request.date.weekday)}'
                                  : DateFormat('d MMMM, EEEE', 'ru').format(request.date),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${request.startTime} - ${request.endTime}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Первое занятие: ${DateFormat('d MMMM', 'ru').format(group.slots.first.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => isRecurring
                        ? _rejectRecurringGroup(group)
                        : _rejectRequest(request),
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Отклонить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => isRecurring
                        ? _approveRecurringGroup(group)
                        : _approveRequest(request),
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Подтвердить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(ScheduleSlot request) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Подтвердить запись?'),
          content: Text(
            'Ученик будет записан на занятие ${DateFormat('d MMMM', 'ru').format(request.date)} с ${request.startTime} до ${request.endTime}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Подтвердить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _scheduleService.approveBooking(request.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запрос подтверждён'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        _refreshList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(ScheduleSlot request) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Отклонить запрос?'),
          content: Text(
            'Слот будет освобождён и ученик получит уведомление об отказе.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Назад'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text('Отклонить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _scheduleService.rejectBooking(request.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запрос отклонён, слот освобождён'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );

        _refreshList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _approveRecurringGroup(BookingRequestGroup group) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Подтвердить постоянное расписание?'),
          content: Text(
            'Будет подтверждено ${group.count} занятий:\n'
            'Каждый ${_getDayName(group.firstSlot.date.weekday)} с ${group.firstSlot.startTime} до ${group.firstSlot.endTime}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Подтвердить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final count = await _scheduleService.approveRecurringGroup(group.recurringGroupId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Подтверждено постоянное расписание ($count занятий)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectRecurringGroup(BookingRequestGroup group) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Отклонить постоянное расписание?'),
          content: Text(
            'Будет отклонено ${group.count} занятий. Все слоты будут освобождены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Назад'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text('Отклонить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final count = await _scheduleService.rejectRecurringGroup(group.recurringGroupId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Отклонено постоянное расписание ($count занятий)'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getDayName(int weekday) {
    const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    return days[weekday - 1];
  }
}
