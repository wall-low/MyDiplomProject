// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:p7/components/user_tile.dart';
import 'package:p7/models/chat.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/chat_service.dart';
import 'package:p7/service/databases.dart';
import 'chat_page.dart';

// УДАЛЕНО: import 'package:cloud_firestore/cloud_firestore.dart';
// УДАЛЕНО: import 'dart:async' и Timer - больше не нужны!
// Мигрировали на PocketBase с realtime подписками через WebSocket
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final ChatService _chatService = ChatService();
  final Auth _auth = Auth();

  String getCurrentUser(){
    return _auth.getCurrentUid();
  }

  @override
  void initState() {
    super.initState();
    // Никаких дополнительных действий - Stream подключится автоматически
  }

  @override
  void dispose() {
    // НОВОЕ: Отписываемся от realtime подписок
    _chatService.unsubscribeFromChats();
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
              child: Text("Ошибка: ${snapshot.error}"),
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
                  receiverUsername: otherUser.username,
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