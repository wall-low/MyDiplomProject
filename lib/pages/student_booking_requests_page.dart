import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_slot.dart';
import '../service/auth.dart';
import '../service/databases.dart';
import '../service/schedule_service.dart';

/// Страница запросов ученика на бронирование
///
/// Функции:
/// - Просмотр своих pending запросов (ожидают подтверждения)
/// - Просмотр confirmed запросов (подтверждены репетитором)
/// - Отмена pending запросов
class StudentBookingRequestsPage extends StatefulWidget {
  const StudentBookingRequestsPage({super.key});

  @override
  State<StudentBookingRequestsPage> createState() =>
      _StudentBookingRequestsPageState();
}

class _StudentBookingRequestsPageState
    extends State<StudentBookingRequestsPage> {
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
          'Мои запросы',
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

  /// Список запросов
  Widget _buildRequestsList(ColorScheme colorScheme) {
    return FutureBuilder<List<ScheduleSlot>>(
      key: ValueKey(_refreshKey),
      future: _scheduleService.getStudentRequests(_auth.getCurrentUid()),
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
                  Icons.event_available,
                  size: 80,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'Нет активных запросов',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Найдите репетитора и забронируйте занятие!',
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

        // Разделяем на pending и confirmed
        final pendingRequests =
            requests.where((slot) => slot.isPending).toList();
        final confirmedRequests =
            requests.where((slot) => slot.isConfirmed).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pending запросы
            if (pendingRequests.isNotEmpty) ...[
              Text(
                '⏳ Ожидают подтверждения',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...pendingRequests.map((request) => _buildRequestCard(
                    request,
                    colorScheme,
                    isPending: true,
                  )),
            ],

            // Разделитель
            if (pendingRequests.isNotEmpty && confirmedRequests.isNotEmpty)
              const SizedBox(height: 24),

            // Confirmed запросы
            if (confirmedRequests.isNotEmpty) ...[
              Text(
                '✅ Подтверждены',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...confirmedRequests.map((request) => _buildRequestCard(
                    request,
                    colorScheme,
                    isPending: false,
                  )),
            ],
          ],
        );
      },
    );
  }

  /// Карточка запроса
  Widget _buildRequestCard(
    ScheduleSlot request,
    ColorScheme colorScheme, {
    required bool isPending,
  }) {
    final statusColor = isPending ? Colors.orange : Colors.green;
    final statusText = isPending ? 'Ожидает подтверждения' : 'Подтверждено';

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
            // Информация о репетиторе
            FutureBuilder(
              future: _db.getUserFromPocketBase(request.tutorId),
              builder: (context, userSnapshot) {
                final tutorName = userSnapshot.hasData
                    ? userSnapshot.data!.name
                    : 'Загрузка...';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          statusColor.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tutorName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                isPending
                                    ? Icons.hourglass_empty
                                    : Icons.check_circle,
                                size: 14,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Информация о слоте
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('d MMMM, EEEE', 'ru')
                              .format(request.date),
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
            ),

            // Кнопка отмены (только для pending)
            if (isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelRequest(request),
                  icon: Icon(Icons.close, size: 18),
                  label: Text('Отменить запрос'),
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
            ],
          ],
        ),
      ),
    );
  }

  /// Отменить запрос
  Future<void> _cancelRequest(ScheduleSlot request) async {
    try {
      // Показываем диалог подтверждения
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Отменить запрос?'),
          content: Text(
            'Отменить запрос на занятие ${DateFormat('d MMMM', 'ru').format(request.date)} с ${request.startTime} до ${request.endTime}?',
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
              child: Text('Отменить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Отменяем запрос
      await _scheduleService.cancelBooking(request.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запрос отменён'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Обновляем список
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
}
