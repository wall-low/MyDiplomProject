import 'package:flutter/material.dart';
import 'package:p7/service/chat_service.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final String userID;
  final String messageID;
  final bool isCurrentUser;
  final DateTime? timestamp;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.userID,
    required this.messageID,
    this.timestamp,
  });

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

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
                  'Пожаловаться на сообщение',
                  style: TextStyle(color: cs.onSurface),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  _reportDialog(pageCtx);
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
    final reasonController = TextEditingController();

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(
          'Пожаловаться на сообщение',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Опишите причину жалобы:',
              style: TextStyle(color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Например: оскорбления, спам...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              reasonController.dispose();
              Navigator.pop(ctx);
            },
            child: Text('Отмена', style: TextStyle(color: cs.secondary)),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              reasonController.dispose();
              ChatService().reportUser(messageID, userID, reason: reason);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Text('Жалоба отправлена'),
                  backgroundColor: cs.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Пожаловаться', style: TextStyle(color: Colors.red)),
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