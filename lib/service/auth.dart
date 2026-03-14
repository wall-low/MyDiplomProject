import 'package:pocketbase/pocketbase.dart';
import 'cache_service.dart';
import 'pocketbase_service.dart';

class Auth {
  final _pb = PocketBaseService().client;

  RecordModel? getCurrentUser() => _pb.authStore.model;

  String getCurrentUid() => _pb.authStore.model?.id ?? '';

  bool isAuthenticated() => _pb.authStore.isValid;

  Future<RecordAuth> loginEmailPassword(String email, String password) async {
    try {
      final authData = await _pb.collection('users').authWithPassword(
        email,
        password,
      );

      print('[Auth] Успешный вход: ${authData.record.data['email']}');
      return authData;
    } on ClientException catch (e) {
      print('[Auth] Ошибка входа: ${e.statusCode} - ${e.response}');
      rethrow;
    } catch (e) {
      print('[Auth] Неизвестная ошибка входа: $e');
      rethrow;
    }
  }

  Future<RecordAuth> registerEmailPassword(String email, String password) async {
    try {
      final emailPrefix = email.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final username = '${emailPrefix}_$timestamp';

      print('[Auth] Создание пользователя: $email (username: $username)');
      await _pb.collection('users').create(body: {
        'email': email,
        'username': username,
        'password': password,
        'passwordConfirm': password,
        'role': 'Ученик',
        'name': 'Временное имя',
        'city': 'Москва',
        'birthDate': '2000-01-01',
      });

      print('[Auth] Автоматический вход после регистрации');
      final authData = await _pb.collection('users').authWithPassword(
        email,
        password,
      );

      print('[Auth] Успешная регистрация: ${authData.record.data['email']}');
      return authData;
    } on ClientException catch (e) {
      print('[Auth] Ошибка регистрации: ${e.statusCode} - ${e.response}');
      rethrow;
    } catch (e) {
      print('[Auth] Неизвестная ошибка регистрации: $e');
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = getCurrentUser();
    if (currentUser == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      await _pb.collection('users').update(
        currentUser.id,
        body: {
          'oldPassword': currentPassword,
          'password': newPassword,
          'passwordConfirm': newPassword,
        },
      );

      print('[Auth] Пароль успешно изменен для ${currentUser.id}');
    } on ClientException catch (e) {
      print('[Auth] Ошибка смены пароля: ${e.statusCode} - ${e.response}');
      rethrow;
    } catch (e) {
      print('[Auth] Неизвестная ошибка смены пароля: $e');
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      await _pb.collection('users').requestPasswordReset(email);

      print('[Auth] Запрос на сброс пароля отправлен на: $email');
    } on ClientException catch (e) {
      print('[Auth] Ошибка запроса сброса пароля: ${e.statusCode} - ${e.response}');

      if (e.statusCode == 404) {
        throw Exception('Пользователь с таким email не найден');
      } else if (e.statusCode == 400) {
        throw Exception('Некорректный email');
      } else {
        throw Exception('Ошибка отправки письма');
      }
    } catch (e) {
      print('[Auth] Неизвестная ошибка запроса сброса пароля: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _pb.authStore.clear();
    await CacheService().clearAll();
    print('[Auth] Пользователь вышел из системы, кэш очищен');
  }
}
