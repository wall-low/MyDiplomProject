import 'package:flutter/material.dart';
import 'package:p7/components/user_avatar.dart';

class UserTile extends StatelessWidget {
  final String text;
  final String? avatarUrl;
  final String? subtitle;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? unreadCount;
  final void Function()? onTap;

  const UserTile({
    super.key,
    required this.text,
    required this.avatarUrl,
    this.subtitle,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount,
    required this.onTap,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Только что';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} мин';
    } else if (diff.inDays < 1) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера';
    } else if (diff.inDays < 7) {
      final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return days[time.weekday - 1];
    } else {
      return '${time.day}.${time.month}.${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primaryContainer,
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          child: Row(
            children: [
              // Аватар
              UserAvatar(
                avatarUrl: avatarUrl,
                size: 56,
              ),
              const SizedBox(width: 16),

              // Текстовая часть
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Имя и время
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(lastMessageTime!),
                            style: TextStyle(
                              color: unreadCount != null && unreadCount! > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                              fontSize: 13,
                              fontWeight: unreadCount != null && unreadCount! > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Последнее сообщение или subtitle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage ?? subtitle ?? '',
                            style: TextStyle(
                              color: unreadCount != null && unreadCount! > 0
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.secondary,
                              fontSize: 14,
                              fontWeight: unreadCount != null && unreadCount! > 0
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Счётчик непрочитанных
                        if (unreadCount != null && unreadCount! > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount! > 99 ? '99+' : '$unreadCount',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}