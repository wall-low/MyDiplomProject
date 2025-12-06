import 'package:pocketbase/pocketbase.dart';
import 'package:p7/models/user.dart';
import 'package:p7/service/auth.dart';
import 'pocketbase_service.dart';

class Databases {
  // ИЗМЕНЕНИЕ 1: Заменили Firestore на PocketBase
  //
  // БЫЛО:
  // final _db = FirebaseFirestore.instance;
  // final _auth = FirebaseAuth.instance;
  //
  // СТАЛО:
  // final _pb = PocketBaseService().client;
  //
  // PocketBaseService - наш Singleton, всегда возвращает один экземпляр
  final _pb = PocketBaseService().client;

  /// Сохранение профиля пользователя после регистрации (2-й шаг)
  ///
  /// БЫЛО (Firestore):
  /// await _db.collection("Users").doc(uid).set(userMap);
  /// set() создавал новый документ или перезаписывал существующий
  ///
  /// СТАЛО (PocketBase):
  /// await _pb.collection('users').update(uid, body: userMap);
  /// update() обновляет существующую запись
  ///
  /// ПОЧЕМУ update(), а не create()?
  /// Потому что пользователь УЖЕ создан в auth.dart при регистрации
  /// (метод registerEmailPassword создает запись в коллекции users)
  /// Здесь мы только ДОПОЛНЯЕМ профиль (name, birthDate, city, role, bio)
  ///
  /// Поля:
  /// - name: имя пользователя
  /// - email: email (уже есть из auth)
  /// - username: генерируется из email (часть до @)
  /// - birthDate: дата рождения
  /// - city: город
  /// - role: роль (student/tutor = "Ученик"/"Репетитор")
  /// - bio: биография (пока пустая)
  Future<void> saveInfoInPocketBase({
    required String name,
    required String email,
    required DateTime birthDate,
    required String city,
    required String role,
  }) async {
    // Получаем ID текущего пользователя
    final uid = Auth().getCurrentUid();

    // ВАЖНО: НЕ генерируем username заново!
    //
    // Username уже был создан в auth.dart при регистрации (с timestamp для уникальности)
    // Здесь мы только обновляем остальные поля (name, birthDate, city, role, bio)
    // Если добавить username в body, он ПЕРЕЗАПИШЕТ существующий уникальный username

    // Создаем Map с полями для обновления (БЕЗ username!)
    final userMap = {
      'name': name,
      'email': email,
      // 'username': НЕ ОБНОВЛЯЕМ! Уже создан в auth.dart
      'birthDate': birthDate.toIso8601String(),
      'city': city,
      'role': role,
      'bio': '',
    };

    try {
      // ИЗМЕНЕНИЕ 3: Обновляем запись в PocketBase
      //
      // БЫЛО (Firestore):
      // await _db.collection("Users").doc(uid).set(userMap);
      //
      // СТАЛО (PocketBase):
      // await _pb.collection('users').update(uid, body: userMap);
      //
      // Отличия:
      // - 'users' (lowercase) - название коллекции в PocketBase
      // - update() вместо set() - обновляем существующую запись
      // - body: userMap - данные для обновления
      await _pb.collection('users').update(uid, body: userMap);

      print('[Databases] Профиль сохранен для пользователя: $uid');
    } on ClientException catch (e) {
      // ClientException - стандартное исключение PocketBase
      print('[Databases] Ошибка сохранения профиля: ${e.statusCode} - ${e.response}');
      rethrow;
    } catch (e) {
      print('[Databases] Неизвестная ошибка сохранения профиля: $e');
      rethrow;
    }
  }

  /// Получение профиля пользователя по ID
  ///
  /// БЫЛО (Firestore):
  /// final userDoc = await _db.collection("Users").doc(uid).get();
  /// return UserProfile.fromDocument(userDoc);
  ///
  /// СТАЛО (PocketBase):
  /// final record = await _pb.collection('users').getOne(uid);
  /// return UserProfile.fromRecord(record);
  ///
  /// Отличия:
  /// - getOne(uid) вместо doc(uid).get()
  /// - Возвращает RecordModel вместо DocumentSnapshot
  /// - fromRecord() вместо fromDocument() - новый метод в модели
  Future<UserProfile?> getUserFromPocketBase(String uid) async {
    try {
      // ИЗМЕНЕНИЕ 4: Получаем запись из PocketBase
      //
      // БЫЛО (Firestore):
      // final userDoc = await _db.collection("Users").doc(uid).get();
      //
      // СТАЛО (PocketBase):
      // final record = await _pb.collection('users').getOne(uid);
      //
      // getOne(uid) - получает одну запись по ID
      // Возвращает RecordModel с полями:
      // - record.id - ID записи
      // - record.data - Map с данными пользователя
      // - record.created - дата создания
      // - record.updated - дата обновления
      final record = await _pb.collection('users').getOne(uid);

      // ИЗМЕНЕНИЕ 5: Преобразуем RecordModel в UserProfile
      //
      // БЫЛО:
      // return UserProfile.fromDocument(userDoc);
      //
      // СТАЛО:
      // return UserProfile.fromRecord(record);
      //
      // fromRecord() - новый метод в lib/models/user.dart
      // Преобразует RecordModel (PocketBase) в UserProfile (наша модель)
      return UserProfile.fromRecord(record);
    } on ClientException catch (e) {
      // 404 - пользователь не найден (профиль не заполнен)
      // 403 - нет прав доступа
      print('[Databases] Ошибка получения профиля: ${e.statusCode} - ${e.response}');
      return null;
    } catch (e) {
      print('[Databases] Неизвестная ошибка получения профиля: $e');
      return null;
    }
  }

  /// Обновление биографии пользователя
  ///
  /// БЫЛО (Firestore):
  /// await _db.collection("Users").doc(uid).update({'bio': bio});
  ///
  /// СТАЛО (PocketBase):
  /// await _pb.collection('users').update(uid, body: {'bio': bio});
  ///
  /// API почти идентичный, только другой синтаксис
  Future<void> updateUserBio(String bio) async {
    String uid = Auth().getCurrentUid();

    try {
      // ИЗМЕНЕНИЕ 6: Обновляем поле bio в PocketBase
      //
      // БЫЛО:
      // await _db.collection("Users").doc(uid).update({'bio': bio});
      //
      // СТАЛО:
      // await _pb.collection('users').update(uid, body: {'bio': bio});
      //
      // body: {'bio': bio} - обновляем только поле bio, остальные поля не трогаем
      await _pb.collection('users').update(uid, body: {'bio': bio});

      print('[Databases] Биография обновлена для: $uid');
    } on ClientException catch (e) {
      print('[Databases] Ошибка обновления биографии: ${e.statusCode} - ${e.response}');
    } catch (e) {
      print('[Databases] Неизвестная ошибка обновления биографии: $e');
    }
  }

  /// Получение списка репетиторов
  ///
  /// БЫЛО (Firestore) - реактивный Stream:
  /// Stream<List<UserProfile>> getTutorsStream() {
  ///   return _db.collection("Users")
  ///     .where('role', isEqualTo: 'Репетитор')
  ///     .snapshots() // <- реактивный поток
  ///     .map((snapshot) => ...);
  /// }
  ///
  /// СТАЛО (PocketBase) - Future (одноразовый запрос):
  /// Future<List<UserProfile>> getTutorsList() async {
  ///   final records = await _pb.collection('users').getList(
  ///     filter: 'role="Репетитор"'
  ///   );
  /// }
  ///
  /// ПОЧЕМУ Future вместо Stream?
  /// - getList() - одноразовый запрос, не реактивный
  /// - Для реактивности нужен subscribe(), но это сложнее
  /// - Можем добавить подписку позже, если нужно
  /// - Для большинства случаев Future достаточно
  ///
  /// PocketBase фильтры:
  /// - filter: 'role="Репетитор"' - SQL-like синтаксис
  /// - Поддерживает: =, !=, >, <, >=, <=, ~, !~, &&, ||
  /// - Пример: filter: 'role="tutor" && city="Moscow"'
  Future<List<UserProfile>> getTutorsList() async {
    try {
      // ИЗМЕНЕНИЕ 7: Запрос репетиторов с фильтром
      //
      // БЫЛО (Firestore):
      // _db.collection("Users").where('role', isEqualTo: 'Репетитор')
      //
      // СТАЛО (PocketBase):
      // _pb.collection('users').getList(filter: 'role="Репетитор"')
      //
      // Отличия в синтаксисе фильтров:
      // Firestore: .where('role', isEqualTo: 'value')
      // PocketBase: filter: 'role="value"' (SQL-like)
      //
      // getList() возвращает ResultList с полями:
      // - items: List<RecordModel> - список записей
      // - page: номер страницы
      // - perPage: количество на странице
      // - totalItems: общее количество
      // - totalPages: всего страниц
      final result = await _pb.collection('users').getList(
        filter: 'role="Репетитор"',
        // Можно добавить параметры:
        // page: 1,
        // perPage: 50,
        // sort: '-created', // сортировка по дате создания (убывание)
      );

      // ИЗМЕНЕНИЕ 8: Преобразуем RecordModel в UserProfile
      //
      // БЫЛО:
      // snapshot.docs.map((doc) => UserProfile.fromDocument(doc))
      //
      // СТАЛО:
      // result.items.map((record) => UserProfile.fromRecord(record))
      //
      // result.items - это List<RecordModel>
      // Преобразуем каждый RecordModel в UserProfile
      final tutors = result.items.map((record) {
        return UserProfile.fromRecord(record);
      }).toList();

      print('[Databases] Найдено репетиторов: ${tutors.length}');
      return tutors;
    } on ClientException catch (e) {
      print('[Databases] Ошибка получения репетиторов: ${e.statusCode} - ${e.response}');
      return [];
    } catch (e) {
      print('[Databases] Неизвестная ошибка получения репетиторов: $e');
      return [];
    }
  }

  /// Получение всех уникальных городов из базы
  ///
  /// БЫЛО (Firestore):
  /// final snapshot = await _db.collection("Users").get();
  /// final cities = snapshot.docs.map((doc) => doc.data()['city'])...
  ///
  /// СТАЛО (PocketBase):
  /// final records = await _pb.collection('users').getFullList();
  /// final cities = records.map((r) => r.data['city'])...
  ///
  /// Отличия:
  /// - getFullList() вместо get() - получает ВСЕ записи без пагинации
  /// - record.data['city'] вместо doc.data()['city']
  /// - Логика обработки городов остается та же
  Future<List<String>> getAllCities() async {
    try {
      // ИЗМЕНЕНИЕ 9: Получаем все записи пользователей
      //
      // БЫЛО (Firestore):
      // final snapshot = await _db.collection("Users").get();
      //
      // СТАЛО (PocketBase):
      // final records = await _pb.collection('users').getFullList();
      //
      // getFullList() - получает ВСЕ записи без пагинации
      // Внимание: если пользователей много (>1000), лучше использовать:
      // - getList() с пагинацией
      // - или SQL агрегацию на стороне сервера
      final records = await _pb.collection('users').getFullList();

      // ИЗМЕНЕНИЕ 10: Извлекаем уникальные города
      //
      // БЫЛО:
      // snapshot.docs.map((doc) => (doc.data()['city'] as String?) ?? '')
      //
      // СТАЛО:
      // records.map((r) => (r.data['city'] as String?) ?? '')
      //
      // Логика:
      // 1. Извлекаем поле 'city' из каждой записи
      // 2. Фильтруем пустые города (.where((city) => city.isNotEmpty))
      // 3. Убираем дубликаты (.toSet())
      // 4. Преобразуем в список (.toList())
      // 5. Сортируем по алфавиту (.sort())
      final cities = records
          .map((record) => (record.data['city'] as String?) ?? '')
          .where((city) => city.isNotEmpty)
          .toSet() // Set автоматически убирает дубликаты
          .toList();

      cities.sort(); // Сортировка по алфавиту

      print('[Databases] Найдено городов: ${cities.length}');
      return cities;
    } on ClientException catch (e) {
      print('[Databases] Ошибка загрузки городов: ${e.statusCode} - ${e.response}');
      return [];
    } catch (e) {
      print('[Databases] Неизвестная ошибка загрузки городов: $e');
      return [];
    }
  }

  /// Обновление полей профиля пользователя
  ///
  /// БЫЛО (Firestore):
  /// await _db.collection("Users").doc(uid).update(updates);
  ///
  /// СТАЛО (PocketBase):
  /// await _pb.collection('users').update(uid, body: updates);
  ///
  /// API идентичный, только другой синтаксис
  ///
  /// Поддерживает частичное обновление:
  /// - Если name == null, поле name не обновляется
  /// - Если city != null, поле city обновляется
  /// - И так далее для всех полей
  Future<void> updateUserProfile({
    String? name,
    String? city,
    String? role,
    String? bio,
  }) async {
    String uid = Auth().getCurrentUid();

    try {
      // Собираем только те поля, которые нужно обновить
      Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (city != null) updates['city'] = city;
      if (role != null) updates['role'] = role;
      if (bio != null) updates['bio'] = bio;

      // Если есть что обновлять
      if (updates.isNotEmpty) {
        // ИЗМЕНЕНИЕ 11: Обновляем запись в PocketBase
        //
        // БЫЛО:
        // await _db.collection("Users").doc(uid).update(updates);
        //
        // СТАЛО:
        // await _pb.collection('users').update(uid, body: updates);
        //
        // body: updates - только измененные поля
        // Неизмененные поля остаются без изменений
        await _pb.collection('users').update(uid, body: updates);

        print('[Databases] Профиль обновлен для: $uid, поля: ${updates.keys}');
      } else {
        print('[Databases] Нечего обновлять, все поля null');
      }
    } on ClientException catch (e) {
      print('[Databases] Ошибка обновления профиля: ${e.statusCode} - ${e.response}');
    } catch (e) {
      print('[Databases] Неизвестная ошибка обновления профиля: $e');
    }
  }
}

/// ВАЖНЫЕ ЗАМЕЧАНИЯ:
///
/// 1. НАЗВАНИЯ КОЛЛЕКЦИЙ:
/// - Firestore: "Users" (с большой буквы)
/// - PocketBase: "users" (lowercase) - стандарт PocketBase
///
/// 2. СИНТАКСИС ФИЛЬТРОВ:
/// - Firestore: .where('field', isEqualTo: 'value')
/// - PocketBase: filter: 'field="value"' (SQL-like синтаксис)
///
/// 3. РЕАКТИВНОСТЬ:
/// - Firestore: .snapshots() - автоматический реактивный Stream
/// - PocketBase: .getList() - одноразовый запрос (Future)
/// - Для реактивности в PocketBase: .subscribe() (сложнее, добавим позже)
///
/// 4. PAGINATION:
/// - getList() - с пагинацией (page, perPage)
/// - getFullList() - все записи сразу (для маленьких коллекций)
///
/// 5. СЛЕДУЮЩИЙ ШАГ:
/// Обновить модель UserProfile в lib/models/user.dart
/// Добавить метод fromRecord() для преобразования RecordModel
