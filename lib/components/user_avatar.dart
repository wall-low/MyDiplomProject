import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {

  final String? avatarUrl;
  final double size;

  const UserAvatar({
    Key? key,
    this.avatarUrl,
    this.size = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2);

    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary,
          borderRadius: radius,
        ),
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
        progress == null
            ? child
            : SizedBox(
          width: size,
          height: size,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorBuilder: (_, __, ___) =>
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: radius,
              ),
              child: Icon(Icons.error, size: size * 0.6),
            ),
      ),
    );
  }
}