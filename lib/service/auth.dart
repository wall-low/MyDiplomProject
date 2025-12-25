import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';

class Auth {
  final _pb = PocketBaseService().client;

  RecordModel? getCurrentUser() => _pb.authStore.model;

  String getCurrentUid() => _pb.authStore.model?.id ?? '';

  bool isAuthenticated() => _pb.authStore.isValid;

  Future<RecordAuth> loginEmailPassword(String email, String password) async {
    try {
      // Авторизация через PocketBase
      final authData = await _pb.collection('users').authWithPassword(
        email,
        password,
      );

      print('[Auth] Успешный вход: ${authData.record.data['email']}');
      return authData;
    } on ClientException catch (e) {
      // ClientException - стандартное исключение PocketBase
      // e.statusCode - HTTP код (400 = неверные данные, 404 = не найден и т.д.)
      // e.response - детали ошибки от сервера
      print('[Auth] Ошибка входа: ${e.statusCode} - ${e.response}');

      // ВАЖНО: Пробрасываем ClientException дальше без оборачивания
      // login_page.dart ловит ClientException и показывает детальные ошибки
      rethrow;
    } catch (e) {
      print('[Auth] Неизвестная ошибка входа: $e');
      rethrow;
    }
  }

  /// Регистрация нового пользователя
  ///
  /// БЫЛО (Firebase):
  /// await _auth.createUserWithEmailAndPassword(email, password);
  /// Создавал пользователя И сразу авторизовывал его (1 шаг)
  ///
  /// СТАЛО (PocketBase) - 2 шага:
  /// 1. create() - создаем пользователя в коллекции users
  /// 2. authWithPassword() - авторизуемся (получаем токен)
  ///
  /// Почему 2 шага:
  /// PocketBase.create() только создает запись, но НЕ авторизует
  /// Нужно явно вызвать authWithPassword для получения токена
  ///
  /// Поля для регистрации:
  /// - email: обязательное (требование Auth Collection)
  /// - username: обязательное (генерируется автоматически из email + timestamp)
  /// - password: обязательное
  /// - passwordConfirm: обязательное (требование PocketBase для безопасности)
  Future<RecordAuth> registerEmailPassword(String email, String password) async {
    try {
      // ВАЖНО: Генерируем username из email
      //
      // PocketBase Auth Collection требует обязательное поле username
      // Генерируем из email: берем часть до @ + timestamp для уникальности
      // Пример: "test@mail.com" → "test_1733414484"
      final emailPrefix = email.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final username = '${emailPrefix}_$timestamp';

      print('[Auth] Создание пользователя: $email (username: $username)');
      await _pb.collection('users').create(body: {
        'email': email,
        'username': username, // ДОБАВЛЕНО: обязательное поле для PocketBase
        'password': password,
        'passwordConfirm': password,
        'role': 'Ученик', // ВРЕМЕННОЕ значение, будет обновлено на RegisterProfilePage
        'name': 'Временное имя', // ВРЕМЕННОЕ значение, будет обновлено на RegisterProfilePage
        'city': 'Москва', // ВРЕМЕННОЕ значение, будет обновлено на RegisterProfilePage
        'birthDate': '2000-01-01', // ВРЕМЕННОЕ значение, будет обновлено на RegisterProfilePage
        // Все эти поля обязательны в PocketBase, но реальные значения пользователь введёт на RegisterProfilePage
      });

      // ШАГ 2: Авторизуемся сразу после регистрации
      print('[Auth] Автоматический вход после регистрации');
      final authData = await _pb.collection('users').authWithPassword(
        email,
        password,
      );

      print('[Auth] Успешная регистрация: ${authData.record.data['email']}');
      return authData;
    } on ClientException catch (e) {
      // Возможные ошибки:
      // 400 - email уже существует, неверный формат email, слабый пароль, отсутствие username
      // 500 - ошибка сервера
      print('[Auth] Ошибка регистрации: ${e.statusCode} - ${e.response}');

      // ВАЖНО: Пробрасываем ClientException дальше без оборачивания
      // register_page.dart ловит ClientException и показывает детальные ошибки
      rethrow;
    } catch (e) {
      print('[Auth] Неизвестная ошибка регистрации: $e');
      rethrow;
    }
  }

  /// Смена пароля текущего пользователя
  ///
  /// БЫЛО (Firebase) - 2 шага:
  /// 1. reauthenticateWithCredential() - реаутентификация для безопасности
  /// 2. updatePassword() - обновление пароля
  ///
  /// СТАЛО (PocketBase) - 1 шаг:
  /// update() с полями oldPassword, password, passwordConfirm
  /// PocketBase сам проверяет oldPassword внутри - проще и безопаснее
  ///
  /// Поля:
  /// - oldPassword: текущий пароль (для проверки)
  /// - password: новый пароль
  /// - passwordConfirm: подтверждение нового пароля
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Проверяем, авторизован ли пользователь
    final currentUser = getCurrentUser();
    if (currentUser == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Обновляем пароль в PocketBase
      // PocketBase автоматически проверит oldPassword
      await _pb.collection('users').update(
        currentUser.id,
        body: {
          'oldPassword': currentPassword, // PocketBase проверит его
          'password': newPassword,
          'passwordConfirm': newPassword,
        },
      );

      print('[Auth] Пароль успешно изменен для ${currentUser.id}');
    } on ClientException catch (e) {
      // Возможные ошибки:
      // 400 - неверный текущий пароль, слабый новый пароль
      // 403 - нет прав (но у нас это текущий пользователь, так что маловероятно)
      print('[Auth] Ошибка смены пароля: ${e.statusCode} - ${e.response}');
      rethrow;
    } catch (e) {
      print('[Auth] Неизвестная ошибка смены пароля: $e');
      rethrow;
    }
  }

  /// Запрос на сброс пароля (отправка email)
  ///
  /// НОВЫЙ МЕТОД для PocketBase
  ///
  /// PocketBase отправит email с ссылкой для сброса пароля
  ///
  /// Параметры:
  /// - email: Email пользователя
  ///
  /// Throws:
  /// - Exception если email не найден или другая ошибка
  Future<void> requestPasswordReset(String email) async {
    try {
      // МЕТОД PocketBase для сброса пароля
      //
      // Отправляет email с ссылкой для сброса пароля
      // Ссылка ведет на PocketBase UI (http://localhost:8090/_/)
      await _pb.collection('users').requestPasswordReset(email);

      print('[Auth] Запрос на сброс пароля отправлен на: $email');
    } on ClientException catch (e) {
      // Возможные ошибки:
      // 400 - некорректный email
      // 404 - пользователь не найден
      print('[Auth] Ошибка запроса сброса пароля: ${e.statusCode} - ${e.response}');

      // Оборачиваем в Exception с понятным сообщением для UI
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

  /// Выход из системы
  ///
  /// БЫЛО (Firebase):
  /// await _auth.signOut(); - асинхронный метод
  ///
  /// СТАЛО (PocketBase):
  /// _pb.authStore.clear(); - синхронный метод
  ///
  /// Почему без await:
  /// authStore.clear() просто удаляет токен из памяти (локальная операция)
  /// Это синхронная операция, не требует await
  ///
  /// Что делает clear():
  /// 1. Удаляет токен из памяти (_pb.authStore.token)
  /// 2. Удаляет данные пользователя (_pb.authStore.model)
  /// 3. Удаляет токен из SharedPreferences (персистентное хранилище)
  Future<void> logout() async {
    _pb.authStore.clear();
    print('[Auth] Пользователь вышел из системы');
  }
}
