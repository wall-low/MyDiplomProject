import 'package:flutter/material.dart';
import 'package:p7/pages/main_navigation.dart';
import 'package:p7/pages/register_profile_page.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/models/user.dart';
import 'package:p7/service/cache_service.dart';
import 'package:p7/service/databases.dart';
import 'package:p7/service/login_or_register.dart';
import 'package:p7/service/notification_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<UserProfile?> _loadProfileWithCache(String userId) async {
    final cache = CacheService();

    try {
      final profile = await Databases().getUserFromPocketBase(userId);
      if (profile != null) {
        await cache.saveUserProfile(profile);
        return profile;
      }
      final cached = await cache.getCachedUserProfile();
      if (cached != null) {
        debugPrint('[AuthGate] Профиль из кэша (сервер вернул null)');
        return cached;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthGate] Сервер недоступен, берём профиль из кэша: $e');
      return await cache.getCachedUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Auth();

    return Scaffold(
      body: _buildBody(context, auth),
    );
  }

  Widget _buildBody(BuildContext context, Auth auth) {
    debugPrint('[AuthGate] Проверка авторизации: ${auth.isAuthenticated()}');

    if (auth.isAuthenticated()) {
      final userId = auth.getCurrentUid();
      final userEmail = auth.getCurrentUser()?.data['email'] as String? ?? '';

      debugPrint('[AuthGate] Пользователь авторизован: $userId, email: $userEmail');

      return FutureBuilder(
        future: _loadProfileWithCache(userId),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            debugPrint('[AuthGate] Загрузка профиля...');
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          if (profileSnapshot.hasData && profileSnapshot.data != null) {
            debugPrint('[AuthGate] Профиль найден: ${profileSnapshot.data?.name}');
            // Запускаем уведомления
            NotificationService().startPolling(userId);
            return const MainNavigation();
          }

          debugPrint('[AuthGate] Профиль не найден: ${profileSnapshot.error}');
          return RegisterProfilePage(
            email: userEmail,
          );
        },
      );
    }

    return const LoginOrRegister();
  }
}
