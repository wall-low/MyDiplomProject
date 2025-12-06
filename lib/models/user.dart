import 'package:pocketbase/pocketbase.dart';

/// Модель профиля пользователя
///
/// Мигрировано с Firestore на PocketBase
/// Добавлен метод fromRecord() для преобразования RecordModel (PocketBase)
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String username;
  final DateTime birthDate;
  final String city;
  final String role;
  final String bio;
  final String? avatarUrl;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    required this.birthDate,
    required this.city,
    required this.role,
    required this.bio,
    this.avatarUrl,
  });

  /// Создание UserProfile из RecordModel (PocketBase)
  ///
  /// НОВЫЙ МЕТОД для работы с PocketBase
  ///
  /// RecordModel - это объект который возвращает PocketBase при запросах:
  /// - record.id - ID записи в коллекции users
  /// - record.data - Map<String, dynamic> с данными пользователя
  /// - record.created - дата создания записи
  /// - record.updated - дата последнего обновления
  ///
  /// Поля из record.data:
  /// - name: имя пользователя
  /// - email: email (из Auth Collection)
  /// - username: username (из Auth Collection или сгенерирован)
  /// - birthDate: дата рождения в формате ISO 8601 (строка "2000-01-01")
  /// - city: город
  /// - role: роль ("Ученик" или "Репетитор")
  /// - bio: биография
  /// - avatar: имя файла аватара (не URL!)
  ///
  /// ВАЖНО про avatar:
  /// В PocketBase avatar - это имя файла (например: "avatar_abc123.jpg")
  /// Полный URL генерируется через PocketBaseService.getFileUrl()
  /// Здесь мы пока оставляем только имя файла
  factory UserProfile.fromRecord(RecordModel record) {
    // Получаем данные из record.data
    final data = record.data;

    // ИЗМЕНЕНИЕ 1: Парсинг birthDate из строки ISO 8601
    //
    // БЫЛО (Firestore):
    // final Timestamp ts = data['birthDate'] as Timestamp;
    // final DateTime date = ts.toDate();
    //
    // СТАЛО (PocketBase):
    // PocketBase хранит даты в формате ISO 8601 строки: "2000-01-01"
    // DateTime.parse() автоматически парсит ISO 8601
    DateTime parsedBirthDate;
    try {
      final birthDateStr = data['birthDate'] as String?;
      if (birthDateStr != null && birthDateStr.isNotEmpty) {
        parsedBirthDate = DateTime.parse(birthDateStr);
      } else {
        parsedBirthDate = DateTime.now(); // Fallback
      }
    } catch (e) {
      print('[UserProfile] Ошибка парсинга birthDate: $e');
      parsedBirthDate = DateTime.now(); // Fallback
    }

    // ИЗМЕНЕНИЕ 2: Получаем avatar как имя файла (не URL)
    //
    // БЫЛО (Firestore):
    // avatarUrl: data['avatarUrl'] as String? - полный URL от Cloudinary
    //
    // СТАЛО (PocketBase):
    // avatar: data['avatar'] as String? - только имя файла
    //
    // Полный URL генерируется в UI через:
    // PocketBaseService().getFileUrl(record, avatar)
    final avatar = data['avatar'] as String?;

    return UserProfile(
      // ИЗМЕНЕНИЕ 3: uid берем из record.id, а не из data['uid']
      //
      // БЫЛО (Firestore):
      // uid: data['uid'] as String - UID хранился в документе
      //
      // СТАЛО (PocketBase):
      // uid: record.id - ID записи = ID пользователя
      //
      // В PocketBase ID записи и есть UID пользователя
      uid: record.id,

      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      username: data['username'] as String? ?? '',
      birthDate: parsedBirthDate,
      city: data['city'] as String? ?? 'Не указан',
      role: data['role'] as String? ?? 'Другое',
      bio: data['bio'] as String? ?? '',

      // avatarUrl пока оставляем как имя файла
      // В UI будем генерировать полный URL через PocketBaseService
      avatarUrl: avatar,
    );
  }

  /// Преобразование UserProfile в Map для отправки в PocketBase
  ///
  /// ИЗМЕНЕНИЯ:
  /// - birthDate: Timestamp.fromDate() → birthDate.toIso8601String()
  /// - Убрали поле 'uid' - в PocketBase uid = record.id (не хранится в data)
  ///
  /// PocketBase автоматически парсит ISO 8601 строки в date тип
  Map<String, dynamic> toMap() {
    return {
      // ИЗМЕНЕНИЕ 4: Убрали 'uid' из Map
      //
      // БЫЛО (Firestore):
      // 'uid': uid, - UID хранился в документе
      //
      // СТАЛО (PocketBase):
      // uid не нужен в body - это ID записи, передается отдельно
      //
      // В PocketBase:
      // pb.collection('users').update(uid, body: {...})
      //                         ^^^        ^^^^
      //                         ID         данные (без ID)

      'name': name,
      'email': email,
      'username': username,

      // ИЗМЕНЕНИЕ 5: Преобразование DateTime в ISO 8601 строку
      //
      // БЫЛО (Firestore):
      // 'birthDate': Timestamp.fromDate(birthDate) - Firestore Timestamp
      //
      // СТАЛО (PocketBase):
      // 'birthDate': birthDate.toIso8601String() - ISO 8601 строка
      //
      // Пример: DateTime(2000, 1, 15) → "2000-01-15T00:00:00.000"
      // PocketBase автоматически распознает и сохраняет как date тип
      'birthDate': birthDate.toIso8601String(),

      'city': city,
      'role': role,
      'bio': bio,

      // avatarUrl - это имя файла (будет обработано отдельно при загрузке)
      if (avatarUrl != null) 'avatar': avatarUrl,
    };
  }

  // Копирование с изменениями
  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? username,
    DateTime? birthDate,
    String? city,
    String? role,
    String? bio,
    String? avatarUrl,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      birthDate: birthDate ?? this.birthDate,
      city: city ?? this.city,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}