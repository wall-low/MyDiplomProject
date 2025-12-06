import 'package:flutter/material.dart';
import 'package:p7/pages/home_page.dart';
import 'package:p7/pages/register_profile_page.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/databases.dart';
import 'package:p7/service/login_or_register.dart';

/// AuthGate - "Ворота" приложения, решает куда направить пользователя
///
/// Мигрировано с Firebase на PocketBase
///
/// Логика:
/// 1. Проверяем авторизацию (authStore.isValid)
/// 2. Если авторизован → проверяем заполнен ли профиль
///    - Профиль не заполнен → RegisterProfilePage (2-й шаг регистрации)
///    - Профиль заполнен → HomePage
/// 3. Если НЕ авторизован → LoginOrRegister
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // ИЗМЕНЕНИЕ 1: Убрали StreamBuilder
    //
    // БЫЛО (Firebase):
    // StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges())
    // Firebase предоставлял реактивный Stream, который автоматически обновлялся
    //
    // СТАЛО (PocketBase):
    // Простая проверка auth.isAuthenticated() в build() методе
    //
    // ПОЧЕМУ ЭТО РАБОТАЕТ:
    // - После login → Navigator.pushReplacement() перестраивает AuthGate
    // - После logout → Navigator.pushReplacement() перестраивает AuthGate
    // - При каждой перестройке вызывается build() и проверяется authStore.isValid
    //
    // Если нужна реактивность (редкий случай), можно использовать:
    // ValueListenableBuilder(valueListenable: pb.authStore, ...)

    final auth = Auth();

    return Scaffold(
      body: _buildBody(context, auth),
    );
  }

  /// Основная логика определения экрана
  Widget _buildBody(BuildContext context, Auth auth) {
    // ИЗМЕНЕНИЕ 2: Заменили snapshot.hasData на auth.isAuthenticated()
    //
    // БЫЛО (Firebase):
    // if (snapshot.hasData) { final user = snapshot.data!; }
    //
    // СТАЛО (PocketBase):
    // if (auth.isAuthenticated()) { final userId = auth.getCurrentUid(); }
    //
    // auth.isAuthenticated() проверяет:
    // 1. Есть ли токен в authStore
    // 2. Не истек ли токен (JWT expiration)
    // 3. Валидна ли подпись токена

    print('[AuthGate] Проверка авторизации: ${auth.isAuthenticated()}');

    if (auth.isAuthenticated()) {
      // Пользователь авторизован
      final userId = auth.getCurrentUid();
      final userEmail = auth.getCurrentUser()?.data['email'] as String? ?? '';

      print('[AuthGate] Пользователь авторизован: $userId, email: $userEmail');

      // ИЗМЕНЕНИЕ 3: getUserFromFirebase → getUserFromPocketBase
      //
      // БЫЛО:
      // Databases().getUserFromFirebase(user.uid)
      //
      // СТАЛО:
      // Databases().getUserFromPocketBase(userId)
      //
      // Метод getUserFromPocketBase мы мигрируем в следующей задаче (Task 3)
      return FutureBuilder(
        future: Databases().getUserFromPocketBase(userId),
        builder: (context, profileSnapshot) {
          // Пока загружается профиль из PocketBase
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            print('[AuthGate] Загрузка профиля...');
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          // ИЗМЕНЕНИЕ 4: Обработка ошибок и пустого профиля
          //
          // Если профиль не найден или произошла ошибка:
          // → Отправляем на RegisterProfilePage (2-й шаг регистрации)
          //
          // Это происходит когда:
          // 1. Пользователь только что зарегистрировался (auth.dart создал запись)
          // 2. Но еще не заполнил доп. поля (name, birthDate, city, role, bio)
          if (profileSnapshot.hasError ||
              !profileSnapshot.hasData ||
              profileSnapshot.data == null) {
            // Профиль не заполнен → 2-й шаг регистрации
            print('[AuthGate] Профиль не найден или ошибка: ${profileSnapshot.error}');
            return RegisterProfilePage(
              email: userEmail,
            );
          }

          // Профиль полностью заполнен → переходим на главную страницу
          print('[AuthGate] Профиль найден: ${profileSnapshot.data?.name}');
          return const HomePage();
        },
      );
    }

    // ИЗМЕНЕНИЕ 5: Пользователь НЕ авторизован
    //
    // БЫЛО (Firebase):
    // if (!snapshot.hasData) return LoginOrRegister();
    //
    // СТАЛО (PocketBase):
    // if (!auth.isAuthenticated()) return LoginOrRegister();
    //
    // auth.isAuthenticated() == false когда:
    // 1. Токен отсутствует в authStore (первый запуск или logout)
    // 2. Токен истек (JWT expiration прошел)
    // 3. Токен невалиден (была ручная модификация)

    return const LoginOrRegister();
  }
}

/// ВАЖНЫЕ ЗАМЕЧАНИЯ:
///
/// 1. РЕАКТИВНОСТЬ:
/// AuthGate НЕ использует Stream, но это нормально!
/// После login/logout вызывается Navigator.pushReplacement(),
/// что перестраивает виджет и проверяет authStore.isValid заново.
///
/// 2. АВТОСОХРАНЕНИЕ ТОКЕНА:
/// PocketBase автоматически сохраняет токен в SharedPreferences.
/// При запуске приложения токен загружается автоматически,
/// поэтому auth.isAuthenticated() сразу вернет true.
///
/// 3. БЕЗОПАСНОСТЬ:
/// authStore.isValid проверяет не только наличие токена,
/// но и его валидность (expiration, signature).
/// Это защита от ручной модификации токена.
///
/// 4. СЛЕДУЮЩИЙ ШАГ:
/// В Task 3 мы мигрируем getUserFromPocketBase() в databases.dart