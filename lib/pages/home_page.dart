// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:p7/components/user_tile.dart';
import 'package:p7/models/chat.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/chat_service.dart';
import 'package:p7/service/databases.dart';
import 'package:p7/service/schedule_service.dart';
import 'chat_page.dart';
import 'booking_requests_page.dart';
import 'student_booking_requests_page.dart';

// УДАЛЕНО: import 'package:cloud_firestore/cloud_firestore.dart';
// УДАЛЕНО: import 'dart:async' и Timer - больше не нужны!
// Мигрировали на PocketBase с realtime подписками через WebSocket
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {

  final ChatService _chatService = ChatService();
  final Auth _auth = Auth();
  final ScheduleService _scheduleService = ScheduleService();
  final Databases _db = Databases();

  bool _isTutor = false; // Роль пользователя
  int _pendingRequestsCount = 0; // Количество запросов

  String getCurrentUser(){
    return _auth.getCurrentUid();
  }

  @override
  void initState() {
    super.initState();
    // Добавляем observer для отслеживания жизненного цикла приложения
    WidgetsBinding.instance.addObserver(this);

    // Загружаем роль пользователя и запускаем подписку на уведомления
    _loadUserRoleAndRequests();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Обновляем счётчик при возврате в приложение
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HomePage] 🔄 Приложение вернулось на передний план, обновляем счётчик');
      _loadUserRoleAndRequests();
    }
  }

  /// Загрузить роль пользователя и запустить real-time подписку на запросы
  Future<void> _loadUserRoleAndRequests() async {
    try {
      final user = await _db.getUserFromPocketBase(_auth.getCurrentUid());
      if (user != null && mounted) {
        setState(() {
          _isTutor = user.role == 'Репетитор';
        });

        // Запускаем real-time подписку на pending запросы
        _subscribeToPendingRequests();
      }
    } catch (e) {
      debugPrint('[HomePage] Ошибка загрузки роли: $e');
    }
  }

  /// Подписаться на real-time обновления pending запросов
  ///
  /// Использует PocketBase realtime subscriptions для автоматического обновления
  /// счётчика колокольчика при изменении статусов бронирования
  void _subscribeToPendingRequests() {
    final userId = _auth.getCurrentUid();

    Stream<int> countStream;

    if (_isTutor) {
      // Репетитор: подписываемся на запросы от учеников
      debugPrint('[HomePage] 🔔 Подписка на запросы репетитора');
      countStream = _scheduleService.getPendingRequestsCountStream(userId);
    } else {
      // Ученик: подписываемся на свои pending запросы
      debugPrint('[HomePage] 🔔 Подписка на запросы ученика');
      countStream = _scheduleService.getStudentPendingCountStream(userId);
    }

    // Слушаем изменения и обновляем UI
    countStream.listen(
      (count) {
        if (mounted) {
          debugPrint('[HomePage] 🔔 Обновление счётчика: $count');
          setState(() {
            _pendingRequestsCount = count;
          });
        }
      },
      onError: (error) {
        debugPrint('[HomePage] ❌ Ошибка подписки: $error');
      },
    );
  }

  @override
  void dispose() {
    // Убираем observer жизненного цикла
    WidgetsBinding.instance.removeObserver(this);

    // Отписываемся от realtime подписок
    _chatService.unsubscribeFromChats();
    _scheduleService.unsubscribeFromSlots();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Ч А Т Ы"),
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // Колокольчик с уведомлениями о запросах (для всех пользователей)
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined),
                onPressed: () async {
                  // Переход на разные страницы в зависимости от роли
                  if (_isTutor) {
                    // Репетитор → запросы от учеников
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BookingRequestsPage(),
                      ),
                    );
                  } else {
                    // Ученик → свои запросы
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentBookingRequestsPage(),
                      ),
                    );
                  }
                  // УДАЛЕНО: _loadPendingRequestsCount();
                  // Счётчик обновляется автоматически через realtime subscription!
                },
              ),
              // Бейдж с количеством запросов
              if (_pendingRequestsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _pendingRequestsCount > 9 ? '9+' : '$_pendingRequestsCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList(){
    // НОВОЕ: Используем getChatsStream() с REALTIME подписками!
    //
    // ПРЕИМУЩЕСТВА:
    // ✅ 1 запрос вместо группировки сотен messages
    // ✅ Встроенные счётчики непрочитанных
    // ✅ Уже отсортировано по lastTimestamp
    // ✅ Автоматическое обновление через WebSocket БЕЗ мерцания экрана
    // ✅ Мгновенная реакция на новые сообщения
    //
    // Realtime подписки работают аналогично ChatPage
    return StreamBuilder<List<Chat>>(
        stream: _chatService.getChatsStream(), // Realtime stream вместо Future
        builder: (context, snapshot){

          if (snapshot.hasError){
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить чаты',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Проверьте подключение к серверу',
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting){
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            // Пустой список - убираем RefreshIndicator (не нужен с realtime!)
            return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Нет активных чатов',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Найдите репетитора и начните общение!',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
          }

          // Список чатов - убираем RefreshIndicator, realtime обновляется автоматически!
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              return _buildChatListItem(chats[index], context);
            },
          );
        },
    );
  }

  Widget _buildChatListItem(Chat chat, BuildContext context) {
    // Получаем ID собеседника
    final currentUserId = getCurrentUser();
    final otherUserId = chat.getOtherUserId(currentUserId);

    // Получаем количество непрочитанных для текущего пользователя
    final unreadCount = chat.getUnreadCount(currentUserId);

    // Загружаем данные собеседника
    return FutureBuilder(
      future: Databases().getUserFromPocketBase(otherUserId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          // Показываем плейсхолдер пока грузятся данные пользователя
          return UserTile(
            text: 'Загрузка...',
            avatarUrl: null,
            lastMessage: chat.getLastMessagePreview(),
            lastMessageTime: chat.lastTimestamp,
            unreadCount: unreadCount > 0 ? unreadCount : null,
            onTap: () {},
          );
        }

        final otherUser = userSnapshot.data!;

        return UserTile(
          text: otherUser.name, // ИСПРАВЛЕНО: используем name вместо username
          avatarUrl: otherUser.avatarUrl,
          lastMessage: chat.getLastMessagePreview(),
          lastMessageTime: chat.lastTimestamp,
          unreadCount: unreadCount > 0 ? unreadCount : null,
          onTap: () async {
            // Переходим в чат и ждём возврата
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  receiverName: otherUser.name, // ИЗМЕНЕНО: передаём name
                  receiverID: otherUserId,
                ),
              ),
            );

            // УДАЛЕНО: _refreshChats() - больше не нужен, realtime обновится автоматически!
          },
        );
      },
    );
  }
}