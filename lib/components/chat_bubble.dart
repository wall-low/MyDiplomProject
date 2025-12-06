import 'package:flutter/material.dart';
import 'package:p7/service/chat_service.dart';

// УДАЛЕНО: import 'package:cloud_firestore/cloud_firestore.dart';
// Мигрировали на PocketBase, используем DateTime вместо Timestamp

class ChatBubble extends StatelessWidget {
  final String message;
  final String userID;
  final String messageID;
  final bool isCurrentUser;
  final DateTime? timestamp; // ИЗМЕНЕНО: Timestamp → DateTime

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.userID,
    required this.messageID,
    this.timestamp,
  });

  // ИЗМЕНЕНО: Timestamp → DateTime
  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    // БЫЛО: final date = timestamp.toDate();
    // СТАЛО: timestamp уже DateTime
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void _showOptions(BuildContext pageCtx) {
    final cs = Theme.of(pageCtx).colorScheme;

    showModalBottomSheet(
      context: pageCtx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Полоска сверху
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.flag_outlined, color: cs.primary),
                title: Text(
                  'Пожаловаться',
                  style: TextStyle(color: cs.onSurface),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  _reportDialog(pageCtx);
                },
              ),
              ListTile(
                leading: Icon(Icons.block_outlined, color: Colors.red),
                title: Text(
                  'Заблокировать',
                  style: TextStyle(color: cs.onSurface),
                ),
                onTap: () async {
                  final confirmed = await _blockDialog(pageCtx);
                  Navigator.pop(sheetCtx);
                  if (confirmed == true) Navigator.pop(pageCtx);
                },
              ),
              const Divider(height: 20),
              ListTile(
                leading: Icon(Icons.close, color: cs.secondary),
                title: Text(
                  'Отмена',
                  style: TextStyle(color: cs.secondary),
                ),
                onTap: () => Navigator.pop(sheetCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reportDialog(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(
          'Пожаловаться на сообщение',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Вы уверены, что хотите пожаловаться на это сообщение?',
          style: TextStyle(color: cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: cs.secondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ChatService().reportUser(messageID, userID);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Text('Жалоба отправлена'),
                  backgroundColor: cs.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Пожаловаться',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _blockDialog(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;

    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(
          'Заблокировать пользователя',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Вы уверены, что хотите заблокировать этого пользователя? Вы больше не сможете получать от него сообщения.',
          style: TextStyle(color: cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: cs.secondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await ChatService().blockUser(userID);
              Navigator.pop(ctx, true);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Text('Пользователь заблокирован'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Заблокировать',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (!isCurrentUser) {
          _showOptions(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isCurrentUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isCurrentUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          _formatTime(timestamp),
                          style: TextStyle(
                            color: isCurrentUser
                                ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                                : Theme.of(context).colorScheme.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}