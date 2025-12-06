# Database Schema (PocketBase)

## Обзор

**Backend:** PocketBase (self-hosted, SQLite-based)
**Admin UI:** http://localhost:8090/_/
**API Base URL:** http://localhost:8090/api/

### Преимущества PocketBase
- ✅ Self-hosted - полный контроль, можно хостить на российских серверах
- ✅ Один исполняемый файл - простой деплой
- ✅ Встроенная Admin UI для управления данными
- ✅ Realtime subscriptions (WebSocket)
- ✅ Встроенное файловое хранилище (замена Cloudinary)
- ✅ Authentication из коробки (email/password, OAuth)
- ✅ SQLite - проще для диплома, никогда не заблокируют

### Архитектурные решения

#### Two-Table Chat Pattern
PocketBase НЕ поддерживает subcollections (в отличие от Firestore). Решение - разделение на две коллекции:
- **`messages`** - все сообщения (data layer)
- **`chats`** - метаданные чатов для быстрого списка (metadata layer)

**Преимущества:**
- 1 запрос вместо загрузки 500+ сообщений
- Производительность: 100-300ms вместо 2-5 секунд

---

## Collections

### 1. users (Auth Collection) ✅ МИГРИРОВАНО

**Описание:** Пользователи приложения (репетиторы и ученики)

**Поля:**
| Поле | Тип | Обязательное | Уникальное | Описание |
|------|-----|--------------|------------|----------|
| id | text | ✅ | ✅ | Auto-generated (15 chars) |
| email | email | ✅ | ✅ | Email для входа |
| emailVisibility | bool | - | - | Показывать email публично |
| verified | bool | - | - | Email подтверждён |
| username | text | ✅ | ✅ | Уникальное имя пользователя |
| name | text | ✅ | - | Полное имя |
| birthDate | date | - | - | Дата рождения |
| city | text | - | - | Город проживания |
| role | select | ✅ | - | "student" или "tutor" |
| bio | text | - | - | Описание профиля (макс 500 символов) |
| avatar | file | - | - | Аватар (single, max 5MB, png/jpg/jpeg) |
| created | date | ✅ | - | Auto (дата создания) |
| updated | date | ✅ | - | Auto (дата обновления) |

**Дополнительные поля Auth Collection (встроенные):**
- `password` - хеш пароля (скрыт в API)
- `tokenKey` - для auth sessions
- `passwordResetToken` - для восстановления пароля

**API Rules:**
- **listRule:** `""` (пустое = разрешено всем)
- **viewRule:** `""` (любой может просмотреть профиль)
- **createRule:** `""` (регистрация открыта)
- **updateRule:** `id = @request.auth.id` (только свой профиль)
- **deleteRule:** `id = @request.auth.id` (только свой аккаунт)

**Индексы:**
- `CREATE INDEX idx_users_city ON users(city)` - для поиска по городу
- `CREATE INDEX idx_users_role ON users(role)` - для фильтрации репетиторов

**Пример использования:**
```dart
// Регистрация
final user = await pb.collection('users').create(body: {
  'email': email,
  'password': password,
  'passwordConfirm': password,
  'username': username,
  'name': name,
  'role': 'student',
});

// Вход
final authData = await pb.collection('users').authWithPassword(email, password);

// Обновление профиля
await pb.collection('users').update(userId, body: {'bio': 'Новое описание'});

// Загрузка аватара
final formData = FormData();
formData.files.add(MapEntry('avatar', MultipartFile.fromFileSync(file.path)));
await pb.collection('users').update(userId, body: formData);

// URL аватара
final avatarUrl = pb.getFileUrl(userRecord, userRecord.data['avatar']);
```

---

### 2. messages (Base Collection) ✅ МИГРИРОВАНО

**Описание:** Все сообщения в чатах (текст, изображения, аудио)

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| chatRoomId | text | ✅ | Формат: "uid1_uid2" (отсортированы алфавитно) |
| senderId | relation | ✅ | → users (cascade delete) |
| senderEmail | text | ✅ | Email отправителя |
| receiverId | relation | ✅ | → users (cascade delete) |
| message | text | ✅ | Текст сообщения или URL файла |
| type | select | ✅ | "text" / "image" / "audio" |
| isRead | bool | - | По умолчанию: false |
| created | date | ✅ | Auto (timestamp сообщения) |

**API Rules:**
- **listRule:** `senderId = @request.auth.id || receiverId = @request.auth.id`
- **viewRule:** `senderId = @request.auth.id || receiverId = @request.auth.id`
- **createRule:** `senderId = @request.auth.id`
- **updateRule:** `receiverId = @request.auth.id` (только пометка isRead)
- **deleteRule:** `senderId = @request.auth.id`

**Индексы:**
- `CREATE INDEX idx_messages_chatroom ON messages(chatRoomId, created)` - для загрузки истории чата
- `CREATE INDEX idx_messages_sender ON messages(senderId)`
- `CREATE INDEX idx_messages_receiver ON messages(receiverId, isRead)` - для подсчёта непрочитанных

**Пример использования:**
```dart
// Отправка текстового сообщения
await pb.collection('messages').create(body: {
  'chatRoomId': chatRoomId,
  'senderId': senderId,
  'senderEmail': senderEmail,
  'receiverId': receiverId,
  'message': messageText,
  'type': 'text',
  'isRead': false,
});

// Загрузка истории чата
final messages = await pb.collection('messages').getList(
  filter: 'chatRoomId="$chatRoomId"',
  sort: 'created',
  expand: 'senderId,receiverId',
);

// Пометка как прочитанное
await pb.collection('messages').update(messageId, body: {'isRead': true});

// Подсчёт непрочитанных
final unreadCount = await pb.collection('messages').getList(
  filter: 'receiverId="$userId" && isRead=false',
  perPage: 1,
  skipTotal: false,
).then((result) => result.totalItems);
```

---

### 3. chats (Base Collection) ✨ NEW - МИГРИРОВАНО

**Описание:** Метаданные чатов для быстрого отображения списка чатов (HomePage)

**Назначение:**
- Хранит последнее сообщение, время, счётчики непрочитанных
- Обновляется автоматически после каждой отправки сообщения
- Решает проблему производительности (1 запрос вместо загрузки всех messages)

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| chatRoomId | text | ✅ | Формат: "uid1_uid2" (мин 1, макс 200 символов) |
| user1Id | relation | ✅ | → users (cascade delete) |
| user2Id | relation | ✅ | → users (cascade delete) |
| lastMessage | text | - | Текст последнего сообщения (макс 500 символов) |
| lastMessageType | select | ✅ | "text" / "image" / "audio" |
| lastSenderId | relation | - | → users (кто отправил последнее сообщение) |
| lastTimestamp | date | ✅ | Время последнего сообщения |
| unreadCountUser1 | number | - | Непрочитанные для user1 (мин 0) |
| unreadCountUser2 | number | - | Непрочитанные для user2 (мин 0) |
| created | date | ✅ | Auto |
| updated | date | ✅ | Auto |

**API Rules:**
- **listRule:** `user1Id = @request.auth.id || user2Id = @request.auth.id`
- **viewRule:** `user1Id = @request.auth.id || user2Id = @request.auth.id`
- **createRule:** `user1Id = @request.auth.id || user2Id = @request.auth.id`
- **updateRule:** `user1Id = @request.auth.id || user2Id = @request.auth.id`
- **deleteRule:** `user1Id = @request.auth.id || user2Id = @request.auth.id`

**Пример использования:**
```dart
// Создание/обновление метаданных после отправки сообщения
Future<void> _createOrUpdateChatRoom({
  required String chatRoomId,
  required String user1Id,
  required String user2Id,
  required String lastMessage,
  required String lastMessageType,
  required String lastSenderId,
  required String receiverId,
}) async {
  final existing = await pb.collection('chats').getList(
    filter: 'chatRoomId="$chatRoomId"',
    perPage: 1,
  );

  final isUser1Receiver = receiverId == user1Id;
  final body = {
    'chatRoomId': chatRoomId,
    'user1Id': user1Id,
    'user2Id': user2Id,
    'lastMessage': lastMessage,
    'lastMessageType': lastMessageType,
    'lastSenderId': lastSenderId,
    'lastTimestamp': DateTime.now().toIso8601String(),
  };

  if (existing.items.isNotEmpty) {
    final chat = existing.items.first;
    final currentUnreadUser1 = chat.data['unreadCountUser1'] ?? 0;
    final currentUnreadUser2 = chat.data['unreadCountUser2'] ?? 0;

    body['unreadCountUser1'] = isUser1Receiver ? currentUnreadUser1 + 1 : currentUnreadUser1;
    body['unreadCountUser2'] = !isUser1Receiver ? currentUnreadUser2 + 1 : currentUnreadUser2;

    await pb.collection('chats').update(chat.id, body: body);
  } else {
    body['unreadCountUser1'] = isUser1Receiver ? 1 : 0;
    body['unreadCountUser2'] = !isUser1Receiver ? 1 : 0;
    await pb.collection('chats').create(body: body);
  }
}

// Получение списка чатов для HomePage
final chats = await pb.collection('chats').getList(
  filter: 'user1Id="$currentUserId" || user2Id="$currentUserId"',
  sort: '-lastTimestamp',
  expand: 'user1Id,user2Id',
);
```

---

### 4. slots (Base Collection) ✅ МИГРИРОВАНО

**Описание:** Расписание репетиторов и бронирования занятий

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| tutorId | relation | ✅ | → users (cascade delete) |
| date | date | ✅ | Дата занятия (normalized to 00:00:00) |
| startTime | text | ✅ | Формат: "HH:mm" (например, "09:00") |
| endTime | text | ✅ | Формат: "HH:mm" (например, "10:00") |
| isBooked | bool | - | По умолчанию: false |
| isPaid | bool | - | По умолчанию: false (оплачено через приложение) |
| studentId | relation | - | → users (опционально, заполняется при брони) |
| created | date | ✅ | Auto |
| updated | date | ✅ | Auto |

**API Rules:**
- **listRule:** `""` (любой может просмотреть расписание)
- **viewRule:** `""`
- **createRule:** `tutorId = @request.auth.id` (только репетитор создаёт слоты)
- **updateRule:** `tutorId = @request.auth.id || (studentId = @request.auth.id && isBooked = false)` (репетитор или ученик при брони)
- **deleteRule:** `tutorId = @request.auth.id`

**Индексы:**
- `CREATE INDEX idx_slots_tutor_date ON slots(tutorId, date)`
- `CREATE INDEX idx_slots_student ON slots(studentId)`

**Пример использования:**
```dart
// Репетитор добавляет слот
await pb.collection('slots').create(body: {
  'tutorId': tutorId,
  'date': date.toIso8601String(),
  'startTime': '09:00',
  'endTime': '10:00',
  'isBooked': false,
  'isPaid': false,
});

// Получение доступных слотов на дату
final slots = await pb.collection('slots').getList(
  filter: 'tutorId="$tutorId" && date="$dateStr" && isBooked=false',
  sort: 'startTime',
);

// Бронирование слота учеником
await pb.collection('slots').update(slotId, body: {
  'isBooked': true,
  'studentId': studentId,
});

// Отмена брони
await pb.collection('slots').update(slotId, body: {
  'isBooked': false,
  'studentId': null,
});
```

---

### 5. blocked_users (Base Collection) ✅ МИГРИРОВАНО

**Описание:** Список заблокированных пользователей

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| userId | relation | ✅ | → users (кто блокирует) |
| blockedUserId | relation | ✅ | → users (кого блокируют) |
| created | date | ✅ | Auto |

**API Rules:**
- **listRule:** `userId = @request.auth.id`
- **viewRule:** `userId = @request.auth.id`
- **createRule:** `userId = @request.auth.id`
- **updateRule:** `userId = @request.auth.id`
- **deleteRule:** `userId = @request.auth.id`

**Индексы:**
- `CREATE UNIQUE INDEX idx_blocked_unique ON blocked_users(userId, blockedUserId)` - один пользователь блокирует другого только один раз

**Пример использования:**
```dart
// Блокировка пользователя
await pb.collection('blocked_users').create(body: {
  'userId': currentUserId,
  'blockedUserId': targetUserId,
});

// Получение списка заблокированных
final blocked = await pb.collection('blocked_users').getList(
  filter: 'userId="$currentUserId"',
  expand: 'blockedUserId',
);

// Разблокировка
await pb.collection('blocked_users').delete(recordId);
```

---

### 6. reports (Base Collection) ✅ МИГРИРОВАНО

**Описание:** Жалобы на сообщения

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| reportedBy | relation | ✅ | → users (кто пожаловался) |
| messageId | relation | ✅ | → messages (на какое сообщение) |
| messageOwnerId | relation | ✅ | → users (владелец сообщения) |
| created | date | ✅ | Auto |

**API Rules:**
- **listRule:** `""` (только для администраторов)
- **viewRule:** `""`
- **createRule:** `reportedBy = @request.auth.id`
- **updateRule:** `""` (только для администраторов)
- **deleteRule:** `""` (только для администраторов)

**Пример использования:**
```dart
// Жалоба на сообщение
await pb.collection('reports').create(body: {
  'reportedBy': currentUserId,
  'messageId': messageId,
  'messageOwnerId': messageOwnerId,
});
```

---

## Планируемые коллекции (для диплома)

### 7. tutor_profiles (Base Collection) 🔄 TODO

**Описание:** Расширенные профили репетиторов (предметы, цены, опыт, образование)

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| userId | relation | ✅ | → users (unique, только для role="tutor") |
| subjects | json | ✅ | Массив предметов: ["Математика", "Физика"] |
| priceMin | number | - | Минимальная цена за занятие (руб/час) |
| priceMax | number | - | Максимальная цена за занятие (руб/час) |
| experience | number | - | Опыт работы (лет) |
| education | text | - | Образование (название вуза, специальность) |
| lessonFormat | json | - | Массив: ["online", "offline", "both"] |
| rating | number | - | Средний взвешенный рейтинг (0.0-5.0) |
| totalPaidLessons | number | - | Количество оплаченных занятий (всего) |
| lastPaidLessonDate | date | - | Дата последнего оплаченного занятия |
| isNewbie | bool | - | true если totalPaidLessons = 0 |
| created | date | ✅ | Auto |
| updated | date | ✅ | Auto |

**API Rules:**
- **listRule:** `""` (любой может просмотреть)
- **viewRule:** `""`
- **createRule:** `userId = @request.auth.id`
- **updateRule:** `userId = @request.auth.id`
- **deleteRule:** `userId = @request.auth.id`

**Индексы:**
- `CREATE INDEX idx_tutor_rating ON tutor_profiles(rating DESC)`
- `CREATE INDEX idx_tutor_price ON tutor_profiles(priceMin, priceMax)`

**Пример использования:**
```dart
// Создание профиля репетитора
await pb.collection('tutor_profiles').create(body: {
  'userId': tutorId,
  'subjects': ['Математика', 'Физика'],
  'priceMin': 800,
  'priceMax': 1500,
  'experience': 5,
  'education': 'МГУ, Математический факультет',
  'lessonFormat': ['online', 'offline'],
  'rating': 0.0,
  'totalPaidLessons': 0,
  'isNewbie': true,
});

// Поиск репетиторов по предмету
final tutors = await pb.collection('tutor_profiles').getList(
  filter: 'subjects~"Математика"', // contains
  sort: '-rating',
  expand: 'userId',
);

// Фильтр по цене
final tutors = await pb.collection('tutor_profiles').getList(
  filter: 'priceMin<=${maxPrice} && priceMax>=${minPrice}',
  expand: 'userId',
);
```

---

### 8. reviews (Base Collection) 🔄 TODO

**Описание:** Отзывы учеников о репетиторах

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| tutorId | relation | ✅ | → users (репетитор) |
| studentId | relation | ✅ | → users (ученик) |
| rating | number | - | Оценка 1-5 (только если isVerified=true) |
| comment | text | - | Текстовый отзыв (макс 1000 символов) |
| isVerified | bool | ✅ | true если отзыв после оплаченного занятия |
| lessonId | relation | - | → slots (на какое занятие отзыв) |
| weight | number | - | Вес отзыва (количество оплаченных занятий с этим репетитором) |
| created | date | ✅ | Auto |
| updated | date | ✅ | Auto |

**API Rules:**
- **listRule:** `""` (любой может просмотреть отзывы)
- **viewRule:** `""`
- **createRule:** `studentId = @request.auth.id`
- **updateRule:** `studentId = @request.auth.id`
- **deleteRule:** `studentId = @request.auth.id`

**Индексы:**
- `CREATE INDEX idx_reviews_tutor_date ON reviews(tutorId, created DESC)`
- `CREATE UNIQUE INDEX idx_reviews_unique ON reviews(tutorId, studentId)` - один отзыв от ученика к репетитору

**Бизнес-логика:**
1. **Verified review** (isVerified=true):
   - Доступен только после оплаченного занятия
   - Содержит рейтинг (1-5 звёзд) + опциональный комментарий
   - Участвует в расчёте среднего рейтинга репетитора
   - Вес зависит от количества занятий: weight = count(оплаченных занятий между студентом и репетитором)

2. **Unverified review** (isVerified=false):
   - Доступен любому ученику (даже без оплаченных занятий)
   - Содержит только текстовый комментарий (БЕЗ рейтинга)
   - НЕ участвует в расчёте рейтинга
   - Помечается бейджем "⚠️ Неверифицированный отзыв"

3. **Расчёт рейтинга:**
   - Учитываются только verified reviews за последние 6 месяцев
   - Weighted average: `SUM(rating * weight) / SUM(weight)`
   - Новые репетиторы (0 оплаченных занятий) показывают бейдж "🆕 Новичок на платформе"

**Пример использования:**
```dart
// Создание verified review после оплаченного занятия
await pb.collection('reviews').create(body: {
  'tutorId': tutorId,
  'studentId': studentId,
  'rating': 5,
  'comment': 'Отличный репетитор!',
  'isVerified': true,
  'lessonId': slotId,
  'weight': paidLessonsCount, // количество оплаченных занятий с этим репетитором
});

// Создание unverified review (без оплаты)
await pb.collection('reviews').create(body: {
  'tutorId': tutorId,
  'studentId': studentId,
  'comment': 'Попробовал первое занятие, понравилось',
  'isVerified': false,
  'weight': 0,
});

// Получение отзывов за последние 6 месяцев
final sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
final reviews = await pb.collection('reviews').getList(
  filter: 'tutorId="$tutorId" && isVerified=true && created>="${sixMonthsAgo.toIso8601String()}"',
  expand: 'studentId',
  sort: '-created',
);

// Расчёт weighted average rating
double calculateRating(List<Review> reviews) {
  if (reviews.isEmpty) return 0.0;
  double totalWeightedRating = 0;
  int totalWeight = 0;
  for (var review in reviews) {
    totalWeightedRating += review.rating * review.weight;
    totalWeight += review.weight;
  }
  return totalWeight > 0 ? totalWeightedRating / totalWeight : 0.0;
}
```

---

### 9. payments (Base Collection) 🔄 TODO

**Описание:** Транзакции оплаты (имитация для диплома)

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| studentId | relation | ✅ | → users (ученик) |
| tutorId | relation | ✅ | → users (репетитор) |
| slotId | relation | ✅ | → slots (оплаченное занятие) |
| amount | number | ✅ | Сумма оплаты (руб) |
| status | select | ✅ | "pending" / "completed" / "failed" |
| created | date | ✅ | Auto |
| updated | date | ✅ | Auto |

**API Rules:**
- **listRule:** `studentId = @request.auth.id || tutorId = @request.auth.id`
- **viewRule:** `studentId = @request.auth.id || tutorId = @request.auth.id`
- **createRule:** `studentId = @request.auth.id`
- **updateRule:** `""` (только система обновляет статус)
- **deleteRule:** `""`

**Индексы:**
- `CREATE INDEX idx_payments_student ON payments(studentId, created DESC)`
- `CREATE INDEX idx_payments_tutor ON payments(tutorId, created DESC)`
- `CREATE UNIQUE INDEX idx_payments_slot ON payments(slotId)` - одна оплата на один слот

**Пример использования:**
```dart
// Имитация оплаты занятия
await pb.collection('payments').create(body: {
  'studentId': studentId,
  'tutorId': tutorId,
  'slotId': slotId,
  'amount': 1000,
  'status': 'completed', // для диплома сразу completed
});

// Обновление слота
await pb.collection('slots').update(slotId, body: {
  'isPaid': true,
});

// Обновление профиля репетитора
await pb.collection('tutor_profiles').update(profileId, body: {
  'totalPaidLessons+': 1, // инкремент
  'lastPaidLessonDate': DateTime.now().toIso8601String(),
  'isNewbie': false,
});

// История оплат ученика
final payments = await pb.collection('payments').getList(
  filter: 'studentId="$studentId"',
  sort: '-created',
  expand: 'tutorId,slotId',
);
```

---

### 10. subjects (Base Collection) 🔄 TODO

**Описание:** Справочник предметов преподавания

**Поля:**
| Поле | Тип | Обязательное | Уникальное | Описание |
|------|-----|--------------|------------|----------|
| id | text | ✅ | ✅ | Auto-generated |
| name | text | ✅ | ✅ | Название предмета (например, "Математика") |
| category | text | - | - | Категория ("Школьные", "ЕГЭ", "Языки", и т.д.) |
| created | date | ✅ | - | Auto |

**API Rules:**
- **listRule:** `""` (доступен всем)
- **viewRule:** `""`
- **createRule:** `""` (только для администраторов)
- **updateRule:** `""`
- **deleteRule:** `""`

**Пример данных:**
```json
[
  {"name": "Математика", "category": "Школьные предметы"},
  {"name": "Физика", "category": "Школьные предметы"},
  {"name": "Русский язык", "category": "Школьные предметы"},
  {"name": "Английский язык", "category": "Иностранные языки"},
  {"name": "Химия", "category": "Школьные предметы"},
  {"name": "Биология", "category": "Школьные предметы"},
  {"name": "История", "category": "Школьные предметы"},
  {"name": "Обществознание", "category": "Школьные предметы"},
  {"name": "Подготовка к ЕГЭ", "category": "ЕГЭ"},
  {"name": "Программирование", "category": "IT"}
]
```

---

### 11. favorites (Base Collection) 🔄 TODO

**Описание:** Избранные репетиторы пользователей

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| id | text | ✅ | Auto-generated |
| userId | relation | ✅ | → users (ученик) |
| tutorId | relation | ✅ | → users (репетитор) |
| created | date | ✅ | Auto |

**API Rules:**
- **listRule:** `userId = @request.auth.id`
- **viewRule:** `userId = @request.auth.id`
- **createRule:** `userId = @request.auth.id`
- **updateRule:** `userId = @request.auth.id`
- **deleteRule:** `userId = @request.auth.id`

**Индексы:**
- `CREATE UNIQUE INDEX idx_favorites_unique ON favorites(userId, tutorId)` - нельзя добавить дважды

**Пример использования:**
```dart
// Добавление в избранное
await pb.collection('favorites').create(body: {
  'userId': currentUserId,
  'tutorId': tutorId,
});

// Получение избранных репетиторов
final favorites = await pb.collection('favorites').getList(
  filter: 'userId="$currentUserId"',
  expand: 'tutorId',
  sort: '-created',
);

// Удаление из избранного
await pb.collection('favorites').delete(favoriteId);

// Проверка, добавлен ли в избранное
final exists = await pb.collection('favorites').getList(
  filter: 'userId="$currentUserId" && tutorId="$tutorId"',
  perPage: 1,
).then((result) => result.items.isNotEmpty);
```

---

## File Storage (PocketBase)

### Avatar Images
- **Коллекция:** users
- **Поле:** avatar (file type)
- **Ограничения:**
  - Single file (один аватар)
  - Max 5MB
  - Типы: image/png, image/jpeg, image/jpg
- **Upload:**
  ```dart
  final formData = FormData();
  formData.files.add(MapEntry(
    'avatar',
    MultipartFile.fromFileSync(file.path, filename: 'avatar.jpg'),
  ));
  await pb.collection('users').update(userId, body: formData);
  ```
- **Get URL:**
  ```dart
  final avatarUrl = pb.getFileUrl(userRecord, userRecord.data['avatar']);
  // Пример: http://localhost:8090/api/files/users/RECORD_ID/avatar.jpg
  ```

### Chat Messages (Images & Audio) 🔄 TODO

**ТЕКУЩАЯ РЕАЛИЗАЦИЯ:** Используется Cloudinary (внешний сервис)

**ПЛАНИРУЕТСЯ МИГРАЦИЯ на PocketBase Storage:**

1. **Вариант 1: Добавить file поля в messages коллекцию**
   ```
   messages collection:
     - imageFile: file (single, max 10MB, image/*)
     - audioFile: file (single, max 20MB, audio/*)
   ```

2. **Вариант 2: Создать отдельную коллекцию message_files**
   ```
   message_files collection:
     - messageId: relation → messages
     - file: file (single)
     - fileType: select ("image" | "audio")
   ```

**Рекомендация:** Вариант 1 (проще, меньше запросов)

**Преимущества миграции:**
- Убрать зависимость от Cloudinary
- Все файлы в одном месте (PocketBase)
- Упрощение кода
- Без внешних API ключей

---

## Migration Status

### ✅ Completed (Steps 0-3)
1. ✅ **Setup PocketBase** - Docker + Admin UI настроены
2. ✅ **Authentication** - auth.dart мигрирован на PocketBase Auth
3. ✅ **User Profiles** - databases.dart мигрирован
4. ✅ **Chat System** - chat_service.dart + two-table pattern (messages + chats)
5. ✅ **Terminology** - "Преподаватель" → "Репетитор" globally

### 🔄 In Progress (Steps 4-6)
6. 🔄 **Schedule System** - schedule_service.dart (частично мигрирован)
7. 🔄 **Search & Filters** - find_tutor_page.dart (требует доработки)
8. 🔄 **File Uploads** - Cloudinary → PocketBase Storage (планируется)

### 📋 TODO (Diploma Features)
9. 📋 **Extended Tutor Profiles** - tutor_profiles collection
10. 📋 **Reviews & Ratings** - reviews collection + weight calculation
11. 📋 **Payment System** - payments collection (mock для диплома)
12. 📋 **Subjects** - subjects collection (справочник)
13. 📋 **Favorites** - favorites collection

**Progress:** ~50-60% ЗАВЕРШЕНО

---

## Deployment (Production)

### VPS Setup (Russian Hosting)
1. Buy VPS (Timeweb, Selectel, или другой российский хостинг)
2. Install Docker + docker-compose
3. Deploy PocketBase container:
   ```bash
   cd pocketbase
   docker-compose up -d
   ```
4. Setup reverse proxy (Nginx) + SSL (Let's Encrypt):
   ```nginx
   server {
     listen 443 ssl;
     server_name your-domain.com;

     ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
     ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

     location / {
       proxy_pass http://localhost:8090;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
     }
   }
   ```
5. Update Flutter app:
   ```dart
   final pb = PocketBase('https://your-domain.com');
   ```

### Backup Strategy
```bash
# Auto-backup SQLite database every day
0 3 * * * /usr/bin/docker exec pocketbase cp /pb_data/data.db /pb_data/backups/backup_$(date +\%Y\%m\%d).db
```

---

## Query Examples

### Complex Filters
```dart
// Репетиторы по математике в Москве с рейтингом > 4.0 и ценой < 1500
final tutors = await pb.collection('tutor_profiles').getList(
  filter: 'subjects~"Математика" && userId.city="Москва" && rating>=4.0 && priceMin<=1500',
  sort: '-rating',
  expand: 'userId',
);

// Расписание репетитора на неделю
final startDate = DateTime.now();
final endDate = startDate.add(Duration(days: 7));
final slots = await pb.collection('slots').getList(
  filter: 'tutorId="$tutorId" && date>="${startDate.toIso8601String()}" && date<="${endDate.toIso8601String()}"',
  sort: 'date,startTime',
);

// История чатов с непрочитанными сообщениями
final chats = await pb.collection('chats').getList(
  filter: '(user1Id="$userId" && unreadCountUser1>0) || (user2Id="$userId" && unreadCountUser2>0)',
  sort: '-lastTimestamp',
  expand: 'user1Id,user2Id',
);
```

### Realtime Subscriptions
```dart
// Подписка на новые сообщения в чате
pb.collection('messages').subscribe('*', (e) {
  if (e.action == 'create') {
    final message = Message.fromRecord(e.record!);
    setState(() {
      _messages.insert(0, message);
    });
  }
}, filter: 'chatRoomId="$chatRoomId"');

// Отписка
pb.collection('messages').unsubscribe();
```

---

## Performance Optimization

### Recommended Practices
1. **Use expand for relations** - загружает связанные данные одним запросом
   ```dart
   final chats = await pb.collection('chats').getList(
     expand: 'user1Id,user2Id', // JOIN аналог
   );
   ```

2. **Pagination for large lists**
   ```dart
   final page1 = await pb.collection('messages').getList(page: 1, perPage: 50);
   ```

3. **Cache frequently accessed data** (SharedPreferences, Hive)
   ```dart
   // Кешировать список предметов (редко меняется)
   final subjects = await _getSubjectsFromCache();
   ```

4. **Use skipTotal for faster queries** (если не нужен total count)
   ```dart
   final messages = await pb.collection('messages').getList(
     skipTotal: true, // Faster!
   );
   ```

---

## Known Issues

### ⚠️ Требуют проверки
1. ⚠️ **chat_service.dart:174** - Возможная опечатка в markMessagesAsRead()
   - Sorts [userID1, userID1] вместо [userID1, userID2]
   - ТРЕБУЕТ ПРОВЕРКИ И ИСПРАВЛЕНИЯ

2. ⚠️ **chat_service.dart:161** - Возможное несоответствие в getUnreadCount()
   - Queries "message" вместо "messages"
   - ТРЕБУЕТ ПРОВЕРКИ И ИСПРАВЛЕНИЯ

### 🔄 Текущие задачи
1. 🔄 **Cloudinary dependency** - Миграция на PocketBase Storage
2. 🔄 **Realtime chat** - Polling → WebSocket subscriptions (опционально)
3. 🔄 **Schedule service** - Завершить миграцию на PocketBase

---

## Conclusion

Текущая схема базы данных PocketBase обеспечивает:
- ✅ Полная миграция с Firebase (authentication, profiles, chat system)
- ✅ Two-table chat pattern для высокой производительности
- ✅ Self-hosted решение без риска блокировки
- ✅ Простота развёртывания (Docker)
- 📋 Готовность к добавлению фич для диплома (profiles, reviews, payments)

**Следующие шаги:**
1. Завершить миграцию schedule_service.dart
2. Мигрировать файлы с Cloudinary на PocketBase Storage
3. Добавить tutor_profiles, reviews, payments для защиты диплома
