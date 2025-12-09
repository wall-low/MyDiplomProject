import 'package:flutter/material.dart';
import 'package:p7/components/user_tile.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/chat_service.dart';

class BlockedUserPage extends StatelessWidget {
  BlockedUserPage({super.key});

  final ChatService _service = ChatService();


  void _showUnblockBox(BuildContext context, String userID){

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Разблокировать пользователя",style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Text("Вы уверены, что хотите разблокировать этого пользователя?",style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Отмена",style: TextStyle(color: Theme.of(context).colorScheme.primary)
            ),
            ),
            TextButton(
                onPressed: () {
                  _service.unblockUser(userID);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Пользователь разблокирован!",style: TextStyle(color: Theme.of(context).colorScheme.onSurface))
                  ));

                  },
                child: Text("Разблокировать",style: TextStyle(color: Theme.of(context).colorScheme.primary)
                ),

            ),
          ],

        )
    );
  }

  @override
  Widget build(BuildContext context) {

    String userID = Auth().getCurrentUid();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Text("З А Б Л О К И Р О В А Н Н Ы Е", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [],
      ),
      // ИЗМЕНЕНО: StreamBuilder → FutureBuilder
      // ИЗМЕНЕНО: getBlockedUsersStream() → getBlockedUsers()
      //
      // PocketBase использует Future вместо Stream
      body: FutureBuilder<List<Map<String, dynamic>>>(
          future: ChatService().getBlockedUsers(userID),
          builder: (context, snapshot){
            if (snapshot.hasError){
              return Center(
                child: Text("Error loading..", style: TextStyle(color: Theme.of(context).colorScheme.secondary),),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting){
              return Center(
                child: Text("Loading..", style: TextStyle(color: Theme.of(context).colorScheme.secondary),),
              );
            }

            final blockedUsers = snapshot.data ?? [];

            if (blockedUsers.isEmpty){
              return Center(
                child: Text("No blocked users", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
              );
            }

            return ListView.builder(
              itemCount: blockedUsers.length,
              itemBuilder: (context, index) {
                final blockedUser = blockedUsers[index];
                return UserTile(
                  text: blockedUser["name"] ?? "Unknown",
                  avatarUrl: blockedUser["avatarUrl"] ?? "",
                  onTap: () => _showUnblockBox(context, blockedUser['uid']),
                );
              },
            );
          }
      ),
    );
  }
}
