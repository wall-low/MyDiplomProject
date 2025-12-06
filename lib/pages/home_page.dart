// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:p7/components/my_drawer.dart';
import 'package:p7/components/user_tile.dart';
import 'package:p7/models/chat.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/chat_service.dart';
import 'package:p7/service/databases.dart';
import 'chat_page.dart';

// УДАЛЕНО: import 'package:cloud_firestore/cloud_firestore.dart';
// Мигрировали на PocketBase, используем Future вместо Stream
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final ChatService _chatService = ChatService();
  final Auth _auth = Auth();

  // Ключ для обновления FutureBuilder
  int _refreshKey = 0;

  String getCurrentUser(){
    return _auth.getCurrentUid();
  }

  void _refreshChats() {
    setState(() {
      _refreshKey++; // Изменение ключа заставит FutureBuilder перезагрузиться
    });
  }

  @override
  void initState() {
    super.initState();
    // Обновляем список при каждом открытии страницы
    _refreshChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: MyDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Text("C H A T S"),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList(){
    // НОВОЕ: Используем getUserChatsFromMetadata() (БЫСТРО!)
    //
    // ПРЕИМУЩЕСТВА:
    // ✅ 1 запрос вместо группировки сотен messages
    // ✅ Встроенные счётчики непрочитанных
    // ✅ Уже отсортировано по lastTimestamp
    //
    // Используем _refreshKey для автоматического обновления
    return FutureBuilder<List<Chat>>(
        key: ValueKey(_refreshKey), // При изменении ключа FutureBuilder перезагрузится
        future: _chatService.getUserChatsFromMetadata(),
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
            // Пустой список - добавляем RefreshIndicator для обновления
            return RefreshIndicator(
              onRefresh: () async {
                _refreshChats();
                // Ждём немного чтобы анимация завершилась
                await Future.delayed(Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
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
                        const SizedBox(height: 20),
                        Text(
                          '⬇️ Потяните вниз для обновления',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Список чатов - оборачиваем в RefreshIndicator
          return RefreshIndicator(
            onRefresh: () async {
              _refreshChats();
              // Ждём немного чтобы анимация завершилась
              await Future.delayed(Duration(milliseconds: 500));
            },
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                return _buildChatListItem(chats[index], context);
              },
            ),
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
          text: otherUser.username,
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

            // После возврата из чата - обновляем список
            _refreshChats();
          },
        );
      },
    );
  }
}